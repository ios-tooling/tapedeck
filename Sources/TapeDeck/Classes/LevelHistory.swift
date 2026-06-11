//
//  LevelHistory.swift
//  TapeDeck
//
//	 A rolling, timestamped record of recent audio levels, capped at `limit`
//	 samples. Feeds level meters and waveform views.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

@MainActor @Observable public class LevelHistory {
	public struct Sample: Sendable, Codable, Equatable {
		public let timestamp: Date
		public let level: AudioLevel
	}

	public private(set) var samples: [Sample] = []
	public var limit = 5000

	public var current: AudioLevel { samples.last?.level ?? .silent }
	public var duration: TimeInterval {
		guard let first = samples.first, let last = samples.last else { return 0 }
		return last.timestamp.timeIntervalSince(first.timestamp)
	}

	public func reset() {
		samples = []
	}

	public func recent(_ count: Int) -> [Sample] {
		Array(samples.suffix(count))
	}

	public func samples(inLast interval: TimeInterval) -> [Sample] {
		guard let last = samples.last else { return [] }
		let cutoff = last.timestamp.addingTimeInterval(-interval)
		return samples.filter { $0.timestamp >= cutoff }
	}

	public func average(over interval: TimeInterval) -> AudioLevel? {
		let recent = samples(inLast: interval)
		guard !recent.isEmpty else { return nil }
		return AudioLevel(decibels: recent.map { $0.level.decibels }.reduce(0, +) / Double(recent.count))
	}

	func record(_ level: AudioLevel, at date: Date = Date()) {
		samples.append(Sample(timestamp: date, level: level))
		if samples.count > limit { samples.removeFirst(samples.count - limit) }
	}
}
