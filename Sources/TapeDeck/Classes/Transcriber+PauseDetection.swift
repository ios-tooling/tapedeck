//
//  Transcriber+PauseDetection.swift
//  TapeDeck
//
//	 Text-driven pause detection: every new phrase restarts a countdown; once
//	 `pauseDuration` elapses with no new text, a `.paused` phase is emitted.
//	 `.speakingStopped` fires with each restart so UI can show the countdown.
//
//  Created by Ben Gottlieb on 7/15/26.
//

import Foundation

public enum SpeechPausePhase: Sendable, Equatable { case speakingStopped(TimeInterval), paused }

public extension Transcriber {
	// every pause phase, as it happens; for await in as many places as you like
	func pausePhases() -> AsyncStream<SpeechPausePhase> {
		pausePhaseRelay.makeStream()
	}

	func cancelPauseTimer() {
		pauseTask?.cancel()
		pauseTask = nil
	}

	internal func restartPauseCountdown(for text: String) {
		guard !text.isEmpty, text != lastPauseText else { return }
		lastPauseText = text
		pausePhaseRelay.yield(.speakingStopped(pauseDuration))
		pauseTask?.cancel()
		pauseTask = Task { [pauseDuration] in
			try? await Task.sleep(for: .seconds(pauseDuration))
			guard !Task.isCancelled else { return }
			pausePhaseRelay.yield(.paused)
		}
	}

	internal func resetPauseDetection() {
		cancelPauseTimer()
		lastPauseText = ""
	}
}
