//
//  SegmentedRecordingChunkInfo.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/13/24.
//

import Suite
import AVFoundation

public struct SegmentedRecordingChunkInfo: Comparable, Sendable, Identifiable {		// File name format: #. <offset>-<duration>.wav
	public var url: URL
	public let start: TimeInterval
	public let duration: TimeInterval
	public let index: Int
	public var end: TimeInterval { start + duration }
	public var id: URL { url }
	
	public static func <(lhs: Self, rhs: Self) -> Bool { lhs.index < rhs.index }
	public static func ==(lhs: Self, rhs: Self) -> Bool { lhs.url == rhs.url }

	public var timeDescription: String {
		start.durationString(style: .seconds, showLeadingZero: true) + " - " + end.durationString(style: .seconds, showLeadingZero: true)
	}
	
	public func play() {
		RecordingPlayer.instance.player.replaceCurrentItem(with: AVPlayerItem(url: url))
		RecordingPlayer.instance.player.play()
	}
	
	public func extractVolumes(count: Int) async throws -> [Volume]? {
		try await url.extractVolumes(count: count)
	}
	
	init?(url: URL) {
		self.url = url
		
		let filename = url.lastPathComponent.replacingOccurrences(of: ";", with: ":")
		let components = filename.components(separatedBy: ".")

		guard
			let index = Int(components.first ?? ""),
			components.count > 2,
			let offset = TimeInterval(string: components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "-").first),
			let duration = TimeInterval(string: components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "-").last) else {
			self.index = 0
			self.start = 0
			self.duration = 0
			print("Failed to setup a segmented recording chunk")
			return nil
		}
		
		self.index = index
		self.start = offset
		self.duration = duration
	}
}

