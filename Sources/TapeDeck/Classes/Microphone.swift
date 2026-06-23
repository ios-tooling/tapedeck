//
//  Microphone.swift
//  TapeDeck
//
//	 Ambient audio level monitoring. Subscribes to the shared AudioSource, so it
//	 can run alongside recording and transcription.
//
//  Created by Ben Gottlieb on 6/10/26.
//

import Foundation
import AVFoundation

@MainActor @Observable public class Microphone {
	public static let instance = Microphone()

	public private(set) var isListening = false
	public private(set) var currentLevel = AudioLevel.silent
	public let history = LevelHistory()

	// calibration: the dB level treated as silence when normalizing
	public var noiseFloor = AudioLevel.defaultNoiseFloor

	public var normalizedLevel: Double { currentLevel.normalized(floor: noiseFloor) }

	// audio-session category/mode used while listening; set before starting. Use
	// `.measurement` to disable automatic gain control for accurate level metering.
	public var sessionConfiguration: AudioSessionConfiguration {
		get { AudioSource.instance.configuration }
		set { AudioSource.instance.configuration = newValue }
	}

	private var subscription: AudioSubscription?
	private var listenTask: Task<Void, Never>?

	public func start(resettingHistory: Bool = false) async throws {
		guard !isListening else { return }
		if resettingHistory { history.reset() }

		let subscription = try await AudioSource.instance.subscribe()
		self.subscription = subscription
		isListening = true

		listenTask = Task { [weak self] in
			for await event in subscription.events {
				guard let self, !Task.isCancelled else { break }
				if case .audio(let captured) = event {
					currentLevel = captured.level
					history.record(captured.level)
				}
			}
		}
	}

	public func stop() {
		guard isListening else { return }

		listenTask?.cancel()
		listenTask = nil
		subscription?.cancel()
		subscription = nil
		isListening = false
		currentLevel = .silent
	}

	public func toggle() async throws {
		if isListening {
			stop()
		} else {
			try await start()
		}
	}

	// MARK: - View monitoring

	// Meter views ref-count their use of the microphone so that overlapping
	// appear/disappear handoffs (e.g. swapping meter styles) keep it running.
	@ObservationIgnored private var monitorCount = 0

	func beginMonitoring() async throws {
		monitorCount += 1
		try await start()
	}

	func endMonitoring() {
		monitorCount = max(0, monitorCount - 1)
		if monitorCount == 0 { stop() }
	}
}
