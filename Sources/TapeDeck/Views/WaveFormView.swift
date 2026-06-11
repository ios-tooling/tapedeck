//
//  WaveFormView.swift
//  TapeDeck
//
//	 A view to examine the audio in an AudioFile (or recording package) over
//	 time: a zoomable, scrubbable detail waveform over a full-length minimap.
//	 When the AudioPlayer is playing this recording, the playhead tracks it and
//	 scrubbing/tapping seeks.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

public struct WaveFormView: View {
	let recording: Recording
	let tint: Color

	@State private var window = ChartWindow.full
	@State private var duration: TimeInterval = 0
	@State private var detailPeaks: [Float] = []
	@State private var overviewPeaks: [Float] = []
	@State private var extractor = WaveformExtractor()

	private let detailBins = 700
	private let overviewBins = 200

	public init(file: AudioFile, tint: Color = .accentColor) {
		self.init(recording: .file(file), tint: tint)
	}

	public init(recording: Recording, tint: Color = .accentColor) {
		self.recording = recording
		self.tint = tint
	}

	public var body: some View {
		VStack(spacing: 8) {
			WaveformDetailView(peaks: detailPeaks, window: $window, duration: duration, playhead: playhead, tint: tint, onSeek: seek)

			WaveformMinimap(samples: overviewPeaks, playhead: playheadFraction, window: window, tint: tint) { fraction in
				if window == .full {
					seek(to: fraction * duration)
				} else {
					window = ChartWindow.centered(on: fraction, span: window.span)
				}
			}
			.frame(maxHeight: 44)
		}
		.task { await loadOverview() }
		.task(id: window) { await loadDetail() }
	}

	private var playhead: TimeInterval? {
		guard AudioPlayer.instance.nowPlaying?.url == recording.url else { return nil }
		return AudioPlayer.instance.currentTime
	}

	private var playheadFraction: Double? {
		guard let playhead, duration > 0 else { return nil }
		return playhead / duration
	}

	private func seek(to time: TimeInterval) {
		guard AudioPlayer.instance.nowPlaying?.url == recording.url else { return }
		Task { await AudioPlayer.instance.seek(to: time) }
	}

	private func loadOverview() async {
		switch recording {
		case .file(let file): duration = (try? await file.duration()) ?? 0
		case .package(let package): duration = package.duration
		}
		guard duration > 0 else { return }

		let sources = WaveformExtractor.Source.sources(for: recording)
		overviewPeaks = (try? await extractor.peaks(sources: sources, range: 0...duration, bins: overviewBins)) ?? []
		if detailPeaks.isEmpty { detailPeaks = overviewPeaks }
	}

	private func loadDetail() async {
		try? await Task.sleep(for: .milliseconds(80))			// debounce while zooming/panning
		guard !Task.isCancelled, duration > 0 else { return }

		let range = (window.start * duration)...max(window.end * duration, window.start * duration + 0.001)
		let sources = WaveformExtractor.Source.sources(for: recording)
		if let peaks = try? await extractor.peaks(sources: sources, range: range, bins: detailBins), !Task.isCancelled {
			detailPeaks = peaks
		}
	}
}
