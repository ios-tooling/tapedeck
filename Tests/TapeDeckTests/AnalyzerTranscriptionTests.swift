//
//  AnalyzerTranscriptionTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/6/26.
//

import Testing
import Foundation
import AVFoundation
@testable import TapeDeck

#if os(macOS)
@MainActor struct AnalyzerTranscriptionTests {
	// synthesize a spoken fixture so the test needs no bundled audio or microphone
	func makeSpokenFixture(_ text: String) throws -> URL {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("analyzer-fixture-\(UUID().uuidString).aiff")
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
		process.arguments = ["-o", url.path, text]
		try process.run()
		process.waitUntilExit()
		try #require(process.terminationStatus == 0)
		return url
	}

	@Test func transcribesSpokenFile() async throws {
		guard #available(macOS 26.0, *) else { return }

		let url = try makeSpokenFixture("The quick brown fox jumps over the lazy dog")
		defer { try? FileManager.default.removeItem(at: url) }

		let backend = AnalyzerBackend()
		let conversation = try await backend.transcribe(url: url, locale: Locale(identifier: "en_US"))

		print("🎤 transcribed: '\(conversation.text)'")
		#expect(conversation.text.lowercased().contains("fox"))
	}

	@MainActor final class UpdateLog {
		var updates: [TranscriptionUpdate] = []
		func add(_ update: TranscriptionUpdate) { updates.append(update) }

		var finalizedText: String {
			updates.compactMap { if case .finalized(let utterance) = $0 { utterance.text } else { nil } }.joined(separator: " ")
		}
	}

	// pushes the fixture through feed() in mic-sized chunks, mirroring the live pipeline
	@Test func liveFeedTranscribesBuffers() async throws {
		guard #available(macOS 26.0, *) else { return }

		let url = try makeSpokenFixture("The quick brown fox jumps over the lazy dog")
		defer { try? FileManager.default.removeItem(at: url) }

		let file = try AVAudioFile(forReading: url)
		let format = file.processingFormat

		let log = UpdateLog()
		let backend = AnalyzerBackend()
		do {
			try await backend.startLive(format: format, locale: Locale(identifier: "en_US")) { update in log.add(update) }
		} catch {
			print("🎤 startLive threw: \(String(describing: error)) — \(error.localizedDescription)")
			throw error
		}

		var sampleTime: AVAudioFramePosition = 0
		while file.framePosition < file.length {
			guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else { break }
			do {
				try file.read(into: buffer, frameCount: 1024)
			} catch {
				print("🎤 file.read threw: \(String(describing: error)) — \(error.localizedDescription)")
				throw error
			}
			if buffer.frameLength == 0 { break }

			let time = AVAudioTime(sampleTime: sampleTime, atRate: format.sampleRate)
			backend.feed(CapturedAudio(buffer: buffer, time: time, level: AudioLevel(buffer: buffer)))
			sampleTime += AVAudioFramePosition(buffer.frameLength)
		}

		await backend.stopLive()

		print("🎤 live transcribed: '\(log.finalizedText)' via \(log.updates.count) updates")
		#expect(log.finalizedText.lowercased().contains("fox"))
	}
}
#endif
