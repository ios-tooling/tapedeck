//
//  LevelHistoryTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Testing
import Foundation
@testable import TapeDeck

@MainActor struct LevelHistoryTests {
	let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

	func populatedHistory(count: Int, secondsApart: TimeInterval = 1) -> LevelHistory {
		let history = LevelHistory()
		for index in 0..<count {
			history.record(AudioLevel(decibels: Double(-index)), at: start.addingTimeInterval(Double(index) * secondsApart))
		}
		return history
	}

	@Test func trimsToLimitDroppingOldest() {
		let history = populatedHistory(count: 10)
		history.limit = 5
		history.record(AudioLevel(decibels: -99), at: start.addingTimeInterval(10))

		#expect(history.samples.count == 5)
		#expect(history.samples.first?.level.decibels == -6)		// oldest were dropped, last 5 of 11 remain
		#expect(history.current.decibels == -99)
	}

	@Test func recentReturnsNewestSamples() {
		let history = populatedHistory(count: 10)

		#expect(history.recent(3).map { $0.level.decibels } == [-7, -8, -9])
		#expect(history.recent(100).count == 10)						// asking for more than exists is safe
	}

	@Test func samplesInLastWindowsByNewestTimestamp() {
		let history = populatedHistory(count: 10)

		#expect(history.samples(inLast: 2.5).count == 3)			// 6.5s cutoff → samples at 7, 8, 9s
		#expect(LevelHistory().samples(inLast: 5).isEmpty)
	}

	@Test func averageIsMeanOfDecibelsInWindow() throws {
		let history = populatedHistory(count: 10)

		let average = try #require(history.average(over: 2.5))	// samples at -7, -8, -9 dB
		#expect(abs(average.decibels - -8) < 0.0001)
		#expect(LevelHistory().average(over: 5) == nil)
	}

	@Test func durationSpansFirstToLastSample() {
		#expect(populatedHistory(count: 10).duration == 9)
		#expect(LevelHistory().duration == 0)
	}
}
