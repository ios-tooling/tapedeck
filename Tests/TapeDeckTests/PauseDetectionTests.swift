//
//  PauseDetectionTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/15/26.
//

import Testing
import Foundation
@testable import TapeDeck

@MainActor
struct PauseDetectionTests {
	@Test func countdownEmitsSpeakingStoppedThenPaused() async throws {
		let transcriber = Transcriber()
		transcriber.pauseDuration = 0.05

		var received: [SpeechPausePhase] = []
		let stream = transcriber.pausePhases()
		let consumer = Task {
			for await phase in stream {
				received.append(phase)
				if phase == .paused { break }
			}
		}

		transcriber.restartPauseCountdown(for: "hello")
		await consumer.value

		#expect(received == [.speakingStopped(0.05), .paused])
	}

	@Test func newTextRestartsCountdown() async throws {
		let transcriber = Transcriber()
		transcriber.pauseDuration = 0.1

		var received: [SpeechPausePhase] = []
		let stream = transcriber.pausePhases()
		let consumer = Task {
			for await phase in stream {
				received.append(phase)
				if phase == .paused { break }
			}
		}

		transcriber.restartPauseCountdown(for: "hello")
		transcriber.restartPauseCountdown(for: "hello")				// unchanged text should not restart
		try await Task.sleep(for: .seconds(0.03))
		transcriber.restartPauseCountdown(for: "hello there")
		await consumer.value

		#expect(received == [.speakingStopped(0.1), .speakingStopped(0.1), .paused])
	}

	@Test func cancelPauseTimerSuppressesPaused() async throws {
		let transcriber = Transcriber()
		transcriber.pauseDuration = 0.05

		var received: [SpeechPausePhase] = []
		let stream = transcriber.pausePhases()
		let consumer = Task {
			for await phase in stream { received.append(phase) }
		}

		transcriber.restartPauseCountdown(for: "hello")
		transcriber.cancelPauseTimer()
		try await Task.sleep(for: .seconds(0.15))
		consumer.cancel()

		#expect(received == [.speakingStopped(0.05)])
	}
}
