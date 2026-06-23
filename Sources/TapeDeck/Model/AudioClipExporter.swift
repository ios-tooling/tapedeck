//
//  AudioClipExporter.swift
//  TapeDeck
//
//	 Stitches a timeline range across timed audio files into a single composition
//	 and exports it to one file. Works for any set of timed sources — segmented
//	 packages or a loose set of chunk files on a shared timeline.
//
//  Created by Ben Gottlieb on 6/21/26.
//

import AVFoundation

public enum AudioClipExporter {
	// one audio file positioned on a shared timeline
	public struct Source: Sendable, Equatable {
		public let url: URL
		public let timelineStart: TimeInterval
		public let duration: TimeInterval

		public init(url: URL, timelineStart: TimeInterval, duration: TimeInterval) {
			self.url = url
			self.timelineStart = timelineStart
			self.duration = duration
		}
	}

	private static let timescale: CMTimeScale = 44_100

	// exports the portion of `sources` overlapping `range` to `destination`
	@discardableResult
	public static func export(_ sources: [Source], range: ClosedRange<TimeInterval>, to destination: URL, format: AudioFormat = .m4a) async throws -> URL {
		let composition = AVMutableComposition()
		guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
			throw TapeDeckError.exportFailed
		}

		var cursor = CMTime.zero
		for source in sources.sorted(by: { $0.timelineStart < $1.timelineStart }) {
			let sourceEnd = source.timelineStart + source.duration
			guard sourceEnd > range.lowerBound, source.timelineStart < range.upperBound else { continue }

			let localStart = max(0, range.lowerBound - source.timelineStart)
			let localEnd = min(source.duration, range.upperBound - source.timelineStart)
			guard localEnd > localStart else { continue }

			let asset = AVURLAsset(url: source.url)
			guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else { continue }
			let timeRange = CMTimeRange(
				start: CMTime(seconds: localStart, preferredTimescale: timescale),
				duration: CMTime(seconds: localEnd - localStart, preferredTimescale: timescale)
			)
			try track.insertTimeRange(timeRange, of: assetTrack, at: cursor)
			cursor = cursor + timeRange.duration
		}

		guard cursor > .zero else { throw TapeDeckError.exportRangeOutOfBounds }
		guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
			throw TapeDeckError.exportFailed
		}

		try? FileManager.default.removeItem(at: destination)
		try await export.export(to: destination, as: format.container == .wav ? .wav : .m4a)
		return destination
	}
}
