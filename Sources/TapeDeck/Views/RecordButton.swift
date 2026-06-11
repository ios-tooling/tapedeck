//
//  RecordButton.swift
//  TapeDeck
//
//	 A button to start/stop recording. The default look is a record circle that
//	 becomes a stop square while recording; pass custom content to restyle it.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

public struct RecordButton<Content: View>: View {
	let startRecording: @MainActor () async throws -> Void
	let didStop: (@MainActor (Recording) -> Void)?
	let content: (AudioRecorder.State) -> Content

	@State private var showingPermissionAlert = false
	private var recorder: AudioRecorder { .instance }

	public init(startRecording: @escaping @MainActor () async throws -> Void, didStop: (@MainActor (Recording) -> Void)? = nil, @ViewBuilder content: @escaping (AudioRecorder.State) -> Content) {
		self.startRecording = startRecording
		self.didStop = didStop
		self.content = content
	}

	public var body: some View {
		Button(action: toggle) {
			content(recorder.state)
		}
		.disabled(recorder.state == .finishing)
		.alert("Microphone Access Denied", isPresented: $showingPermissionAlert) {
			Button("OK") { }
		} message: {
			Text("Authorize microphone access for this app in your device's system settings.")
		}
	}

	private func toggle() {
		Task {
			if recorder.state.isActive {
				if let recording = try? await recorder.stop() { didStop?(recording) }
			} else {
				do {
					try await startRecording()
				} catch TapeDeckError.microphonePermissionDenied {
					showingPermissionAlert = true
				} catch { }
			}
		}
	}
}

extension RecordButton where Content == RecordButtonLabel {
	public init(startRecording: @escaping @MainActor () async throws -> Void, didStop: (@MainActor (Recording) -> Void)? = nil) {
		self.init(startRecording: startRecording, didStop: didStop) { state in
			RecordButtonLabel(state: state)
		}
	}
}

public struct RecordButtonLabel: View {
	let state: AudioRecorder.State

	public var body: some View {
		ZStack {
			Circle()
				.strokeBorder(.secondary, lineWidth: 3)

			RoundedRectangle(cornerRadius: state.isActive ? 4 : 100)
				.fill(.red)
				.padding(state.isActive ? 16 : 6)
				.opacity(state == .finishing ? 0.3 : 1)
		}
		.animation(.easeInOut(duration: 0.2), value: state)
		.aspectRatio(1, contentMode: .fit)
	}
}
