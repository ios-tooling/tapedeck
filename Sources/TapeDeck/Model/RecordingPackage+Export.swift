//
//  RecordingPackage+Export.swift
//  TapeDeck
//
//	 Exports a time range of a segmented recording to a single audio file by
//	 stitching the overlapping chunks into one composition and exporting it.
//
//  Created by Ben Gottlieb on 6/21/26.
//

import AVFoundation

public extension RecordingPackage {
	// exports the given timeline range (clamped to the recording) to `destination`,
	// returning the written URL. The whole recording is exported when range is nil.
	@discardableResult
	func exportClip(range: ClosedRange<TimeInterval>? = nil, to destination: URL, format: AudioFormat = .m4a) async throws -> URL {
		let manifest = try loadManifest()
		guard !manifest.chunks.isEmpty else { throw TapeDeckError.notRecording }

		let total = manifest.chunks.last.map { $0.start + $0.duration } ?? 0
		let lower = max(0, range?.lowerBound ?? 0)
		let upper = min(total, range?.upperBound ?? total)
		guard upper > lower else { throw TapeDeckError.exportRangeOutOfBounds }

		let sources = manifest.chunks.map {
			AudioClipExporter.Source(url: url.appendingPathComponent($0.filename), timelineStart: $0.start, duration: $0.duration)
		}
		return try await AudioClipExporter.export(sources, range: lower...upper, to: destination, format: format)
	}
}
