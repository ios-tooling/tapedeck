//
//  OutputSegmentedRecording.ChunkManager.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/13/24.
//

import AVFoundation
import Suite

extension OutputSegmentedRecording {
	class ChunkManager {
		var url: URL
		var internalType: Recorder.AudioFileType = .wav16k
		var type: Recorder.AudioFileType?
		var chunks: [SegmentedRecordingChunkInfo] = []
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
				chunks = existing.compactMap({ SegmentedRecordingChunkInfo(url: $0)}).sorted()
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
			if let chunk = SegmentedRecordingChunkInfo(url: newURL) { chunks.append(chunk) }
			
			if let durationLimit {
				while storedDuration > (durationLimit + chunkDuration) {
					try? FileManager.default.removeItem(at: chunks[0].url)
					chunks.remove(at: 0)
				}
			}
			return newURL
		}
	}
}
