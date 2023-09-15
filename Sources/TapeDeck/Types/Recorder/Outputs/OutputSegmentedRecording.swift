//
//  OutputSegmentedRecording.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Suite

public class OutputSegmentedRecording: ObservableObject, RecorderOutput {
	var chunks: ChunkManager
	var assetWriter: AVAssetWriter!
	var assetWriterInput: AVAssetWriterInput!
	var chunkDuration: TimeInterval = 5
	var chunkSize: Int64 { Int64(chunkDuration) * sampleRate }
	var sampleRate: Int64 = 44100
	var chunkSamplesRead: Int64 = 0
	var samplesRead: Int64 = 0
	var recordingDuration: TimeInterval = 0
	var outputType = Recorder.AudioFileType.m4a
	var internalType = Recorder.AudioFileType.wav16k
	var currentURL: URL?
	var segmentStartedAt: TimeInterval = 0
	let queue = DispatchQueue(label: "segmented.recording", qos: .userInitiated)
	
	public var containerURL: URL?
	
	public init(in url: URL, outputType: Recorder.AudioFileType = .m4a, bufferDuration: TimeInterval = 30, ringDuration: TimeInterval? = nil) {
		self.containerURL = url
		self.outputType = outputType
		self.chunkDuration = bufferDuration
		chunks = ChunkManager(url: url, type: outputType, durationLimit: ringDuration, chunkDuration: chunkDuration)
	}

	public func handle(buffer sampleBuffer: CMSampleBuffer) {
		queue.async { [weak self] in
			guard let self else { return }
			guard let input = assetWriterInput else {
				print("No current writer configured")
				return
			}
			
			if assetWriter?.status == .unknown {
				print("Unknown writer status")
				return
			}
			
			if !input.append(sampleBuffer) {
				logg("Failed to append buffer, \(self.assetWriter.error?.localizedDescription ?? "unknown error")")
			}
			chunkSamplesRead += Int64(sampleBuffer.numSamples)
			samplesRead += Int64(sampleBuffer.numSamples)
			recordingDuration = TimeInterval(samplesRead / Int64(sampleRate * 1))
			
			if chunkSamplesRead >= chunkSize {
				queue.async {
					try? self.createWriter(startingAt: self.recordingDuration)
				}
			}
		}
	}
	
	public func delete() {
		chunks.clearOut()
	}
	
	public func prepareToRecord() async throws {
		chunks.prepare()

		samplesRead = 0
		recordingDuration = 0

		try self.createWriter(startingAt: 0)
	}
	
	public func endRecording() async throws {
		await closeCurrentWriter(writer: assetWriter, input: assetWriterInput, url: currentURL)
		assetWriterInput = nil
		assetWriter = nil
	}
	
	func createWriter(startingAt offset: TimeInterval) throws {
		let writer = assetWriter
		let writerInput = assetWriterInput
		let url = currentURL
		segmentStartedAt = offset
		
		Task { await closeCurrentWriter(writer: writer, input: writerInput, url: url) }
		assetWriterInput = nil
		assetWriter = nil

		assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: internalType.settings)
		assetWriterInput.expectsMediaDataInRealTime = true
		
		let nextURL = chunks.url(startingAt: offset, duration: chunkDuration)
		
		chunkSamplesRead = 0
		try? FileManager.default.removeItem(at: nextURL)
		assetWriter = try AVAssetWriter(outputURL: nextURL, fileType: internalType.fileType)
		assetWriterInput.expectsMediaDataInRealTime = true
		assetWriter.add(assetWriterInput)
		assetWriter.startWriting()
		assetWriter.startSession(atSourceTime: CMTime.zero)
		self.currentURL = nextURL
	}
	
	func closeCurrentWriter(writer: AVAssetWriter?, input: AVAssetWriterInput?, url: URL?) async {
		guard let input, let writer else { return }
		input.markAsFinished()

		if let current = url {
			Recorder.instance.activeTranscript?.addSegment(start: segmentStartedAt, filename: current.deletingPathExtension().lastPathComponent, samples: 0)
			if writer.status != .completed {
				await writer.finishWriting()
			}
			do {
				try await self.chunks.didFinishWriting(to: current)
			} catch {
				print("Problem finishing the conversion: \(error)")
			}
		}
	}
	
	enum OutputSegmentedRecordingError: Error { case noRecording, outOfRange }
	
	public func extract(range: Range<TimeInterval>?, progress: Binding<Double>? = nil, format: Recorder.AudioFileType = .m4a, to url: URL) async throws -> URL {
		guard chunks.available != nil else {
			throw OutputSegmentedRecordingError.noRecording
		}
		
		let chunks = self.chunks.chunks
		var firstIndex = 0
		var lastIndex = chunks.count - 1
		var startOffset: TimeInterval = 0
		var endDuration: TimeInterval?
		
		if let range = range {
			guard let first = chunks.firstIndex(where: { $0.start <= range.lowerBound && $0.end >= range.lowerBound }) else {
				throw OutputSegmentedRecordingError.outOfRange
			}
			
			firstIndex = first
			startOffset = range.lowerBound - chunks[first].start
			
			if let last = chunks.firstIndex(where: { $0.start <= range.upperBound && $0.end >= range.upperBound }) {
				lastIndex = last
				endDuration = range.upperBound - chunks[lastIndex].start
			}
		}
		
		let urls = Array(chunks[firstIndex...lastIndex]).map { $0.url }
		return try await AudioFileConverter(sources: urls, start: startOffset, endChunkDuration: endDuration, to: format, at: url, progress: progress).convert()
	}

	class ChunkManager {
		var url: URL
		var internalType: Recorder.AudioFileType = .wav16k
		var type: Recorder.AudioFileType?
		var chunks: [ChunkInfo] = []
		var totalChunks = 0
		var durationLimit: TimeInterval?
		let chunkDuration: TimeInterval
		
		init(url: URL, type: Recorder.AudioFileType?, durationLimit: TimeInterval?, chunkDuration: TimeInterval) {
			self.url = url
			self.type = type
			self.durationLimit = durationLimit
			self.chunkDuration = chunkDuration
			
			//RecordingStore.instance.addDirectory(url)
			
			if let existing = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
				chunks = existing.compactMap({ ChunkInfo(url: $0)}).sorted()
				if let first = existing.compactMap({ $0.lastPathComponent.components(separatedBy: ".").first }).first, let count = Int(first) { totalChunks = count }
			}
		}
		
		var available: Range<TimeInterval>? {
			guard let first = chunks.first else { return nil }
			
			var duration = first.duration
			var lastIndex = first.index
			for chunk in chunks.dropFirst() {
				if chunk.index != lastIndex + 1 { break }
				lastIndex = chunk.index
				duration += chunk.duration
			}
			
			return first.start..<(first.start + duration)
		}
		
		func didFinishWriting(to url: URL) async throws {
			guard type != internalType else { return }
			
			let newURL = try await AudioFileConverter.convert(wav: url, toM4A: nil, deleteSource: AudioFileConverter.deleteConversionArtifacts)
			
			if let index = self.chunks.firstIndex(where: { $0.url == url }) {
				self.chunks[index].url = newURL
			}
		}

		func clearOut() {
			try? FileManager.default.removeItem(at: url)
			chunks = []
			totalChunks = 0
		}
		
		func prepare() {
			clearOut()
			try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
		}
		
		var storedDuration: TimeInterval { TimeInterval(chunks.count) * chunkDuration }
		
		func url(startingAt offset: TimeInterval, duration: TimeInterval) -> URL {
			let parent = url
			let ext = internalType.fileExtension
			
			totalChunks += 1
			
			let offsetString = offset.durationString(showLeadingZero: true).replacingOccurrences(of: ":", with: ";")
			let name = "\(String(format: "%06d", totalChunks)). \(offsetString)-\(duration).\(ext)"
			let newURL = parent.appendingPathComponent(name)
			if let chunk = ChunkInfo(url: newURL) { chunks.append(chunk) }
			
			if let durationLimit {
				while storedDuration > (durationLimit + chunkDuration) {
					try? FileManager.default.removeItem(at: chunks[0].url)
					chunks.remove(at: 0)
				}
			}
			return newURL
		}
		
		struct ChunkInfo: Comparable {		// File name format: #. <offset>-<duration>.wav
			var url: URL
			let start: TimeInterval
			let duration: TimeInterval
			let index: Int
			var end: TimeInterval { start + duration }

			static func <(lhs: ChunkInfo, rhs: ChunkInfo) -> Bool { lhs.index < rhs.index }
			static func ==(lhs: ChunkInfo, rhs: ChunkInfo) -> Bool { lhs.url == rhs.url }

			init?(url: URL) {
				self.url = url
				
				let filename = url.lastPathComponent.replacingOccurrences(of: ";", with: ":")
				let components = filename.components(separatedBy: ".")

				guard
					let index = Int(components.first ?? ""),
					components.count > 2,
					let offset = TimeInterval(string: components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "-").first),
					let duration = TimeInterval(string: components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "-").last) else {
					self.index = 0
					self.start = 0
					self.duration = 0
					logg("Failed to setup a segmented recording chunk")
					return nil
				}
				
				self.index = index
				self.start = offset
				self.duration = duration
			}
		}
	}
}
