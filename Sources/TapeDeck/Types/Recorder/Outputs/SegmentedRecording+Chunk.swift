//
//  OutputSegmentedRecording.ChunkManager.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/13/24.
//

import AVFoundation
import Suite

extension OutputSegmentedRecording {
	var chunkURL: URL { containerURL! }
	
	func clearChunks() {
		try? FileManager.default.removeItem(at: chunkURL)
		chunks = []
		totalChunks = 0
	}
	
	func prepare() {
		clearChunks()
		
		if let existing = try? FileManager.default.contentsOfDirectory(at: chunkURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
			chunks = existing.compactMap({ SegmentedRecordingChunkInfo(url: $0)}).sorted()
			if let first = existing.compactMap({ $0.lastPathComponent.components(separatedBy: ".").first }).first, let count = Int(first) { totalChunks = count }
		}

		try? FileManager.default.createDirectory(at: chunkURL, withIntermediateDirectories: true, attributes: nil)
	}
	
	var availableRange: Range<TimeInterval>? {
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
		guard outputType != internalType else { return }
		
		let newURL = try await AudioFileConverter.convert(wav: url, toM4A: nil, deleteSource: AudioFileConverter.deleteConversionArtifacts)
		
		if let index = self.chunks.firstIndex(where: { $0.url == url }) {
			self.chunks[index].url = newURL
		}
	}
	
	var storedDuration: TimeInterval { TimeInterval(chunks.count) * chunkDuration }
	
	func chunkURL(startingAt offset: TimeInterval, duration: TimeInterval) -> URL {
		let parent = chunkURL
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
