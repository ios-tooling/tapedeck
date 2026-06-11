//
//  RecordScreen.swift
//  TapeDeckHarness
//
//	 Live meter (all four styles), recording controls, and mode selection —
//	 exercises Microphone, AudioRecorder, and interruption handling.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI
import TapeDeck

struct RecordScreen: View {
	@State private var style = AmbientSoundView.Style.siriWave
	@State private var isSegmented = false

	private var recorder: AudioRecorder { .instance }

	var body: some View {
		VStack(spacing: 20) {
			Picker("Meter Style", selection: $style) {
				ForEach(AmbientSoundView.Style.allCases, id: \.self) { style in
					Text(style.rawValue).tag(style)
				}
			}
			.pickerStyle(.segmented)

			AmbientSoundView(style: style)
				.frame(maxHeight: 180)
				.id(style)

			RecordingStatusLine(state: recorder.state, duration: recorder.duration)

			Spacer()

			Toggle("Segmented package (30s chunks)", isOn: $isSegmented)
				.disabled(recorder.state.isActive)

			Toggle("Resume after interruptions", isOn: Binding(
				get: { recorder.resumesAfterInterruption },
				set: { recorder.resumesAfterInterruption = $0 }
			))

			RecordButton(startRecording: startRecording) { _ in
				RecordingStore.instance.refresh()
			}
			.frame(width: 76, height: 76)
		}
		.padding()
	}

	private func startRecording() async throws {
		let root = RecordingStore.instance.root ?? URL.documentsDirectory
		let name = Date.now.formatted(.iso8601.dateSeparator(.dash).timeSeparator(.omitted))

		if isSegmented {
			try await recorder.record(packageAt: root.appendingPathComponent(name).appendingPathExtension(RecordingPackage.fileExtension), chunkDuration: 30)
		} else {
			try await recorder.record(to: root.appendingPathComponent(name).appendingPathExtension("m4a"))
		}
	}
}

struct RecordingStatusLine: View {
	let state: AudioRecorder.State
	let duration: TimeInterval

	var body: some View {
		HStack {
			Text(label)
				.foregroundStyle(state == .recording ? .red : .secondary)

			Spacer()

			Text(Duration.seconds(duration), format: .time(pattern: .minuteSecond))
				.monospacedDigit()
		}
		.font(.headline)
	}

	private var label: String {
		switch state {
		case .idle: "Idle"
		case .recording: "● Recording"
		case .paused(let byInterruption): byInterruption ? "Paused (interrupted)" : "Paused"
		case .finishing: "Finishing…"
		}
	}
}
