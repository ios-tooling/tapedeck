//
//  AudioFile.swift
//  TapeDeck
//
//	 A struct representing an on-disk Audio file (mp3, mp4, or whatever formats we support)
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation
import AVFoundation

public struct AudioFile: Sendable, Identifiable, Equatable, Hashable {
	public static let supportedExtensions = ["m4a", "wav", "mp3", "aac", "caf", "aiff", "mp4"]

	public var id: URL { url }

	public let url: URL

	public init(url: URL) {
		self.url = url
	}

	public var name: String { url.deletingPathExtension().lastPathComponent }
	public var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

	public var fileSize: Int? {
		try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
	}

	public var createdAt: Date? {
		try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date
	}

	public func duration() async throws -> TimeInterval {
		try await AVURLAsset(url: url).load(.duration).seconds
	}

	public static func files(in directory: URL) -> [AudioFile] {
		let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
		return contents
			.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
			.map { AudioFile(url: $0) }
			.sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
	}
}
