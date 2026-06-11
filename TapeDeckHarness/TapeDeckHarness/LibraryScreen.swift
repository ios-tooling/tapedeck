//
//  LibraryScreen.swift
//  TapeDeckHarness
//
//	 RecordingStore contents with playback and the zoomable waveform —
//	 exercises AudioPlayer, WaveFormView, and package manifests.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI
import TapeDeck

struct LibraryScreen: View {
	@State private var selected: Recording?

	private var store: RecordingStore { .instance }
	private var player: AudioPlayer { .instance }

	var body: some View {
		VStack(spacing: 0) {
			List {
				ForEach(store.recordings) { recording in
					RecordingRow(recording: recording, isSelected: recording == selected)
						.contentShape(Rectangle())
						.onTapGesture { select(recording) }
				}
				.onDelete(perform: delete)
			}
			.listStyle(.plain)
			.overlay {
				if store.recordings.isEmpty {
					ContentUnavailableView("No Recordings", systemImage: "waveform", description: Text("Record something on the Record tab."))
				}
			}

			if let selected {
				PlaybackPanel(recording: selected)
					.padding()
					.background(.bar)
			}
		}
		.onAppear { store.refresh() }
	}

	private func select(_ recording: Recording) {
		selected = recording
		Task {
			switch recording {
			case .file(let file): try? await player.play(file)
			case .package(let package): try? await player.play(package)
			}
		}
	}

	private func delete(at offsets: IndexSet) {
		for index in offsets {
			let recording = store.recordings[index]
			if recording == selected {
				player.stop()
				selected = nil
			}
			try? store.delete(recording)
		}
	}
}

struct RecordingRow: View {
	let recording: Recording
	let isSelected: Bool

	var body: some View {
		HStack {
			Image(systemName: iconName)
				.foregroundStyle(isSelected ? .blue : .secondary)

			VStack(alignment: .leading) {
				Text(recording.name)
					.lineLimit(1)

				if let created = recording.createdAt {
					Text(created, format: .dateTime)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var iconName: String {
		switch recording {
		case .file: "waveform"
		case .package: "square.stack.3d.up"
		}
	}
}

struct PlaybackPanel: View {
	let recording: Recording

	private var player: AudioPlayer { .instance }
	private var isCurrent: Bool { player.nowPlaying?.url == recording.url }

	var body: some View {
		VStack(spacing: 12) {
			WaveFormView(recording: recording)
				.frame(height: 180)

			HStack {
				Button(action: togglePlayback) {
					Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
						.font(.title)
				}

				if isCurrent {
					Text(Duration.seconds(player.currentTime), format: .time(pattern: .minuteSecond))
						.monospacedDigit()

					ProgressView(value: player.progress)

					Text(Duration.seconds(player.duration), format: .time(pattern: .minuteSecond))
						.monospacedDigit()
				}
			}
		}
	}

	private func togglePlayback() {
		if isCurrent {
			player.isPlaying ? player.pause() : player.resume()
		} else {
			Task {
				switch recording {
				case .file(let file): try? await player.play(file)
				case .package(let package): try? await player.play(package)
				}
			}
		}
	}
}
