//
//  RecordingStoreTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Testing
import Foundation
@testable import TapeDeck

@MainActor struct RecordingStoreTests {
	@Test func scansFilesAndPackagesIgnoringStrays() throws {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: root) }
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

		try Data().write(to: root.appendingPathComponent("memo.m4a"))
		try Data().write(to: root.appendingPathComponent("notes.txt"))								// ignored
		try FileManager.default.createDirectory(at: root.appendingPathComponent("empty.folder"), withIntermediateDirectories: true)	// no manifest: ignored

		let package = RecordingPackage(url: root.appendingPathComponent("session.recording"))
		try package.save(manifest: .init(startedAt: Date(), format: .wav, chunks: [], levels: []))

		let store = RecordingStore()
		store.setup(root: root)

		#expect(store.recordings.count == 2)
		#expect(store.recordings.contains { $0.name == "memo" })
		#expect(store.recordings.contains { $0.name == "session" })

		let memo = store.recordings.first { $0.name == "memo" }!
		try store.delete(memo)
		#expect(store.recordings.count == 1)
		#expect(FileManager.default.fileExists(atPath: memo.url.path) == false)
	}
}
