//
//  RecordingStore.swift
//  TapeDeck
//
//	 An observable library of recordings rooted at a directory: single audio
//	 files and .recording packages, newest first.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

@MainActor @Observable public class RecordingStore {
	public static let instance = RecordingStore()

	public private(set) var recordings: [Recording] = []
	public private(set) var root: URL?

	public func setup(root: URL) {
		self.root = root
		try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		refresh()
	}

	public func refresh() {
		guard let root else { return }

		let contents = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
		recordings = contents
			.compactMap { recording(at: $0) }
			.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
	}

	public func delete(_ recording: Recording) throws {
		try FileManager.default.removeItem(at: recording.url)
		recordings.removeAll { $0.id == recording.id }
	}

	private func recording(at url: URL) -> Recording? {
		let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

		if isDirectory {
			let package = RecordingPackage(url: url)
			return package.exists ? .package(package) : nil
		}

		guard AudioFile.supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }
		return .file(AudioFile(url: url))
	}
}
