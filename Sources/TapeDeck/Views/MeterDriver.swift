//
//  MeterDriver.swift
//  TapeDeck
//
//	 Smooths raw levels toward their targets at ~30Hz with fast attack, slow
//	 release, and decaying peak-hold — shared ballistics for the meter views.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

@MainActor @Observable final class MeterDriver {
	private(set) var values: [Double]
	private(set) var peaks: [Double]

	var attackBlend = 0.55
	var releaseBlend = 0.18
	var peakDecayPerSecond = 0.55

	@ObservationIgnored var targetProvider: @MainActor () -> [Double] = { [] }

	private var tickTask: Task<Void, Never>?
	private var lastTick = Date()

	init(count: Int) {
		values = Array(repeating: 0, count: count)
		peaks = Array(repeating: 0, count: count)
	}

	func start() {
		guard tickTask == nil else { return }
		lastTick = Date()
		tickTask = Task { [weak self] in
			while !Task.isCancelled {
				self?.tick()
				try? await Task.sleep(for: .milliseconds(33))
			}
		}
	}

	func stop() {
		tickTask?.cancel()
		tickTask = nil
	}

	private func tick() {
		let now = Date()
		let elapsed = max(0.001, now.timeIntervalSince(lastTick))
		lastTick = now

		let targets = targetProvider()
		let decay = peakDecayPerSecond * elapsed

		for index in values.indices {
			let goal = min(1, max(0, index < targets.count ? targets[index] : 0))
			let blend = goal > values[index] ? attackBlend : releaseBlend
			values[index] += (goal - values[index]) * blend
			peaks[index] = max(values[index], peaks[index] - decay)
		}
	}
}
