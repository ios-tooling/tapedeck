//
//  AudioFile+Waveform.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/17/26.
//

import Foundation

public extension AudioFile {
	/// A normalized (0...1) peak envelope of the file, downsampled to `bins` values —
	/// ready to hand to `WaveformBars`.
	func waveformPeaks(bins: Int) async -> [Float] {
		let duration = (try? await duration()) ?? 0
		guard duration > 0, bins > 0 else { return [] }

		let extractor = WaveformExtractor()
		let sources = WaveformExtractor.Source.sources(for: .file(self))
		return (try? await extractor.peaks(sources: sources, range: 0...duration, bins: bins)) ?? []
	}
}
