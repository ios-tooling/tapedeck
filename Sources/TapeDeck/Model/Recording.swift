//
//  Recording.swift
//  TapeDeck
//
//	 A finished recording: either a single audio file or a segmented package.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

public enum Recording: Sendable, Identifiable, Equatable {
	case file(AudioFile)
	case package(RecordingPackage)

	public var id: URL { url }

	public var url: URL {
		switch self {
		case .file(let file): file.url
		case .package(let package): package.url
		}
	}

	public var name: String {
		switch self {
		case .file(let file): file.name
		case .package(let package): package.name
		}
	}

	public var createdAt: Date? {
		switch self {
		case .file(let file): file.createdAt
		case .package(let package): (try? package.loadManifest())?.startedAt
		}
	}
}
