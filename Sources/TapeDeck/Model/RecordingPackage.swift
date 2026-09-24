//
//  RecordingPackage.swift
//  TapeDeck
//
//	 A segmented recording on disk: a folder of audio chunks, a manifest.json carrying
//	 chunk timing and an optional transcript, and a levels.jsonl 1Hz level history.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

public struct RecordingPackage: Sendable, Identifiable, Equatable {
	public static let fileExtension = "recording"
	static let manifestFilename = "manifest.json"
	static let levelsFilename = "levels.jsonl"

	public var id: URL { url }
	public let url: URL

	public init(url: URL) {
		self.url = url
	}

	public var manifestURL: URL { url.appendingPathComponent(Self.manifestFilename) }
	public var levelsURL: URL { url.appendingPathComponent(Self.levelsFilename) }
	public var name: String { url.deletingPathExtension().lastPathComponent }
	public var exists: Bool { FileManager.default.fileExists(atPath: manifestURL.path) }

	public func loadManifest() throws -> Manifest {
		try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
	}

	func save(manifest: Manifest) throws {
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		try JSONEncoder().encode(manifest).write(to: manifestURL)
	}

	// the 1Hz level history; packages written before levels.jsonl kept it in the manifest
	public func loadLevels() -> [Manifest.LevelSample] {
		if FileManager.default.fileExists(atPath: levelsURL.path) { return LevelLog.read(from: levelsURL) }
		return (try? loadManifest())?.levels ?? []
	}

	public var chunkFiles: [AudioFile] {
		guard let manifest = try? loadManifest() else { return [] }
		return manifest.chunks.map { AudioFile(url: url.appendingPathComponent($0.filename)) }
	}

	public var duration: TimeInterval {
		guard let manifest = try? loadManifest(), let last = manifest.chunks.last else { return 0 }
		return last.start + last.duration
	}
}

extension RecordingPackage {
	public struct Manifest: Codable, Sendable, Equatable {
		public var startedAt: Date
		public var format: AudioFormat
		public var chunks: [Chunk]
		// only populated by packages written before levels.jsonl; read levels via loadLevels()
		public var levels: [LevelSample]
		public var transcript: TranscribedConversation?

		public struct Chunk: Codable, Sendable, Equatable {
			public var filename: String
			public var start: TimeInterval
			public var duration: TimeInterval
		}

		public struct LevelSample: Codable, Sendable, Equatable {
			public var offset: TimeInterval
			public var level: AudioLevel
		}
	}
}
