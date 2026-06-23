//
//  AudioRecorder.swift
//  TapeDeck
//
//	 Records microphone audio to a single file or a segmented package, off the
//	 shared AudioSource. Auto-pauses on interruptions; opt in to auto-resume via
//	 resumesAfterInterruption.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

@MainActor @Observable public class AudioRecorder {
	public enum State: Equatable, Sendable {
		case idle, recording, paused(byInterruption: Bool), finishing

		public var isActive: Bool { self != .idle }
	}

	public static let instance = AudioRecorder()

	public private(set) var state = State.idle
	public private(set) var duration: TimeInterval = 0
	public private(set) var currentLevel = AudioLevel.silent
	public var resumesAfterInterruption = false

	// audio-session category/mode used while recording; set before starting. Use
	// `.measurement` to disable automatic gain control for accurate level metering.
	public var sessionConfiguration: AudioSessionConfiguration {
		get { AudioSource.instance.configuration }
		set { AudioSource.instance.configuration = newValue }
	}

	private let session = RecordingSession()
	private var subscription: AudioSubscription?
	private var pumpTask: Task<Void, Never>?

	public func record(to url: URL, format: AudioFormat = .m4a) async throws {
		let subscription = try await prepareToRecord()
		guard let input = subscription.format else { throw TapeDeckError.audioEngineUnavailable }

		try await session.start(file: url, format: format, input: input)
		beginPumping(subscription)
	}

	public func record(packageAt url: URL, format: AudioFormat = .m4a, chunkDuration: TimeInterval = 60, ringDuration: TimeInterval? = nil) async throws {
		let subscription = try await prepareToRecord()
		guard let input = subscription.format else { throw TapeDeckError.audioEngineUnavailable }

		try await session.start(package: RecordingPackage(url: url), format: format, chunkDuration: chunkDuration, ringDuration: ringDuration, input: input)
		beginPumping(subscription)
	}

	public func pause() async {
		guard state == .recording else { return }
		await setPaused(true, byInterruption: false)
	}

	public func resume() async {
		guard case .paused = state else { return }
		await setPaused(false, byInterruption: false)
	}

	@discardableResult public func stop() async throws -> Recording {
		guard state.isActive, state != .finishing else { throw TapeDeckError.notRecording }
		state = .finishing

		subscription?.cancel()
		subscription = nil
		await pumpTask?.value
		pumpTask = nil

		defer { state = .idle }
		return try await session.finish()
	}

	private func prepareToRecord() async throws -> AudioSubscription {
		guard !state.isActive else { throw TapeDeckError.alreadyRecording }

		let subscription = try await AudioSource.instance.subscribe()
		self.subscription = subscription
		return subscription
	}

	private func beginPumping(_ subscription: AudioSubscription) {
		state = .recording
		duration = 0
		currentLevel = .silent

		pumpTask = Task { [session, weak self] in
			for await event in subscription.events {
				switch event {
				case .audio(let captured):
					if let duration = await session.handle(captured) {
						self?.duration = duration
						self?.currentLevel = captured.level
					}

				case .interruptionBegan:
					await self?.handleInterruption(began: true, shouldResume: false)

				case .interruptionEnded(let shouldResume):
					await self?.handleInterruption(began: false, shouldResume: shouldResume)

				case .formatChanged(let format):
					await session.handleFormatChange(format)
				}
			}
		}
	}

	private func setPaused(_ paused: Bool, byInterruption: Bool) async {
		await session.setPaused(paused)
		state = paused ? .paused(byInterruption: byInterruption) : .recording
	}

	private func handleInterruption(began: Bool, shouldResume: Bool) async {
		if began {
			guard state == .recording else { return }
			await setPaused(true, byInterruption: true)
		} else {
			guard state == .paused(byInterruption: true), resumesAfterInterruption, shouldResume else { return }
			await setPaused(false, byInterruption: false)
		}
	}
}
