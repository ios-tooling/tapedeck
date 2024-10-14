//
//  OutputSegmentedRecording.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import AVFoundation
import Suite

@globalActor public actor AudioActor: GlobalActor {
	public static let shared = AudioActor()
}

public actor OutputSegmentedRecording: ObservableObject, RecorderOutput {
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
	
	var chunks: [SegmentedRecordingChunkInfo] = []
	var totalChunks = 0
	nonisolated let durationLimit: TimeInterval?

	public var containerURL: URL?
	
	public init(in url: URL, outputType: Recorder.AudioFileType = .m4a, bufferDuration: TimeInterval = 30, ringDuration: TimeInterval? = nil) {
		self.containerURL = url
		self.durationLimit = ringDuration
		self.outputType = outputType
		self.chunkDuration = bufferDuration
	}

	public func handle(buffer sampleBuffer: CMSampleBuffer) {
		guard let input = assetWriterInput else {
			print("No current writer configured")
			return
		}
		
		if assetWriter?.status == .unknown {
			print("Unknown writer status")
			return
		}
		
		if !input.append(sampleBuffer) {
			print("Failed to append buffer, \(self.assetWriter.error?.localizedDescription ?? "unknown error")")
		}
		chunkSamplesRead += Int64(sampleBuffer.numSamples)
		samplesRead += Int64(sampleBuffer.numSamples)
		recordingDuration = TimeInterval(samplesRead / Int64(sampleRate * 1))
		
		if chunkSamplesRead >= chunkSize {
			try? self.createWriter(startingAt: self.recordingDuration)
		}
	}
	
	public func delete() {
		Task { await clearChunks() }
	}
	
	public func prepareToRecord() async throws {
		prepare()

		samplesRead = 0
		recordingDuration = 0

		try self.createWriter(startingAt: 0)
	}
	
	public func endRecording() async throws {
		await closeCurrentWriter(writer: assetWriter, input: assetWriterInput, url: currentURL)
		assetWriterInput = nil
		assetWriter = nil
	}
	
	public var recordingChunkURLs: [URL] {
		get { chunks.map { $0.url } }
	}
	
	public var recordingChunks: [SegmentedRecordingChunkInfo] {
		get { chunks }
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
		
		let nextURL = chunkURL(startingAt: offset, duration: chunkDuration)
		
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
			await Recorder.instance.activeTranscript?.addSegment(start: segmentStartedAt, filename: current.deletingPathExtension().lastPathComponent, samples: 0)
			objectWillChange.sendOnMain()
			if writer.status != .completed {
				await writer.finishWriting()
			}
			do {
				try await didFinishWriting(to: current)
			} catch {
				print("Problem finishing the conversion: \(error)")
			}
		}
	}
	
	enum OutputSegmentedRecordingError: Error { case noRecording, outOfRange }
	
	public func extract(range: Range<TimeInterval>?, progress: Binding<Double>? = nil, format: Recorder.AudioFileType = .m4a, to url: URL) async throws -> URL {
		guard availableRange != nil else {
			throw OutputSegmentedRecordingError.noRecording
		}
		
		let chunks = chunks
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
}

