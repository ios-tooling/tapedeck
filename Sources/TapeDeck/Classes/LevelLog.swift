//
//  LevelLog.swift
//  TapeDeck
//
//	 A segmented recording's 1Hz level history as an append-only JSON Lines file.
//	 Appending keeps the history out of memory and out of manifest.json, which is
//	 rewritten on every chunk rotation — so short chunks stay cheap on long recordings,
//	 and the levels survive a crash. Confined to RecordingSession's actor context.
//
//  Created by Ben Gottlieb on 9/24/26.
//

import Foundation

final class LevelLog {
	typealias Sample = RecordingPackage.Manifest.LevelSample

	private let url: URL
	private var handle: FileHandle?
	private let encoder = JSONEncoder()

	init(url: URL) throws {
		self.url = url
		if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
		try open()
	}

	func append(_ sample: Sample) throws {
		try handle?.write(contentsOf: line(for: sample))
	}

	// ring recordings only: rewrites the file without samples at or before cutoff. The ring
	// window is short, so the file being rewritten is too
	func discard(through cutoff: TimeInterval) throws {
		let kept = Self.read(from: url).filter { $0.offset > cutoff }
		try handle?.close()
		try kept.reduce(into: Data()) { $0 += try line(for: $1) }.write(to: url)
		try open()
	}

	func close() {
		try? handle?.close()
		handle = nil
	}

	static func read(from url: URL) -> [Sample] {
		guard let data = try? Data(contentsOf: url) else { return [] }
		let decoder = JSONDecoder()
		return data.split(separator: UInt8(ascii: "\n")).compactMap { try? decoder.decode(Sample.self, from: Data($0)) }
	}

	private func open() throws {
		handle = try FileHandle(forWritingTo: url)
		try handle?.seekToEnd()
	}

	private func line(for sample: Sample) throws -> Data {
		try encoder.encode(sample) + [UInt8(ascii: "\n")]
	}
}
