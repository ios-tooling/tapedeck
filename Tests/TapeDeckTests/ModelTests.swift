//
//  ModelTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Testing
import Foundation
@testable import TapeDeck

struct ModelTests {
	@Test func conversationCodableRoundTrip() throws {
		let conversation = TranscribedConversation(utterances: [
			Utterance(text: "Hello there.", timeRange: 0..<1.5, confidence: 0.92, isFinal: true),
			Utterance(text: "General Kenobi", timeRange: 1.5..<3.0, confidence: 0.4, speaker: "Grievous"),
		])

		let data = try JSONEncoder().encode(conversation)
		let decoded = try JSONDecoder().decode(TranscribedConversation.self, from: data)

		#expect(decoded == conversation)
	}

	@Test func conversationSeparatesFinalizedAndTentativeText() {
		var conversation = TranscribedConversation()
		conversation.append(Utterance(text: "first sentence.", isFinal: true))
		conversation.replaceTentative(with: Utterance(text: "second sen"))

		#expect(conversation.finalizedText == "first sentence.")
		#expect(conversation.tentativeText == "second sen")
		#expect(conversation.text == "first sentence. second sen")

		conversation.replaceTentative(with: Utterance(text: "second sentence."))
		#expect(conversation.utterances.count == 2)							// tentative was replaced, not stacked

		conversation.replaceTentative(with: nil)
		#expect(conversation.text == "first sentence.")
	}

	@Test func packageManifestRoundTrip() throws {
		let packageURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension(RecordingPackage.fileExtension)
		defer { try? FileManager.default.removeItem(at: packageURL) }

		let package = RecordingPackage(url: packageURL)
		let manifest = RecordingPackage.Manifest(
			startedAt: Date(timeIntervalSinceReferenceDate: 1000),
			format: .wav16k,
			chunks: [
				.init(filename: "0. 0-5.wav", start: 0, duration: 5),
				.init(filename: "1. 5-5.wav", start: 5, duration: 5),
			],
			levels: [.init(offset: 0, level: AudioLevel(decibels: -40))]
		)

		try package.save(manifest: manifest)

		#expect(package.exists)
		#expect(try package.loadManifest() == manifest)
		#expect(package.duration == 10)
		#expect(package.chunkFiles.map { $0.url.lastPathComponent } == ["0. 0-5.wav", "1. 5-5.wav"])
	}

	@Test func audioFileListsSupportedFilesInDirectory() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }

		for name in ["b.m4a", "a.wav", "notes.txt", "c.mp3"] {
			try Data().write(to: dir.appendingPathComponent(name))
		}

		let files = AudioFile.files(in: dir)
		#expect(files.map { $0.url.lastPathComponent } == ["a.wav", "b.m4a", "c.mp3"])
	}
}
