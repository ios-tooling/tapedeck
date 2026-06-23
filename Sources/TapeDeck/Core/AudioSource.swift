//
//  AudioSource.swift
//  TapeDeck
//
//	 The single owner of the microphone. One AVAudioEngine input tap fans captured
//	 buffers out to all subscribers (recorder, level meter, transcriber), so any
//	 combination can run at once. The engine starts with the first subscriber and
//	 stops with the last.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

@MainActor final class AudioSource {
	static let instance = AudioSource()

	// how the iOS audio session is configured when the mic starts; set before the
	// first subscriber starts the engine (a change while running takes effect on the
	// next restart)
	var configuration = AudioSessionConfiguration.playback

	private(set) var inputFormat: AVAudioFormat?
	var isRunning: Bool { isStarted }

	private var engine: AVAudioEngine?
	private var isStarted = false
	private var simulatedTask: Task<Void, Never>?
	private let subscribers = AudioSubscriberRegistry()
	private var notificationTokens: [any NSObjectProtocol] = []

	func subscribe() async throws -> AudioSubscription {
		guard await TapeDeckPermissions.instance.requestMicrophone() else { throw TapeDeckError.microphonePermissionDenied }

		let id = UUID()
		let stream = AsyncStream<AudioEvent> { continuation in
			subscribers.add(id: id, continuation)
			continuation.onTermination = { _ in
				Task { @MainActor in AudioSource.instance.unsubscribe(id) }
			}
		}

		if !isStarted { try start() }
		return AudioSubscription(id: id, events: stream, format: inputFormat)
	}

	func unsubscribe(_ id: UUID) {
		guard subscribers.remove(id) else { return }
		if subscribers.isEmpty { stop() }
	}

	private func start() throws {
		#if targetEnvironment(simulator)
			// the simulator has no real audio input; feed synthetic buffers through the
			// same path so recording and metering can be exercised without a device
			startSimulated()
		#else
			try startEngine()
		#endif
		isStarted = true
	}

	private func startEngine() throws {
		#if os(iOS)
			try AudioSession.instance.activate(configuration)
		#endif

		let engine = AVAudioEngine()
		let format = engine.inputNode.outputFormat(forBus: 0)
		guard format.sampleRate > 0, format.channelCount > 0 else { throw TapeDeckError.audioEngineUnavailable }

		// the tap runs on AVFAudio's realtime messenger queue; it must not inherit
		// this class's main-actor isolation
		engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [subscribers] buffer, time in
			guard let copy = buffer.deepCopy() else { return }
			subscribers.yield(.audio(CapturedAudio(buffer: copy, time: time, level: AudioLevel(buffer: buffer))))
		}

		engine.prepare()
		do {
			try engine.start()
		} catch {
			engine.inputNode.removeTap(onBus: 0)
			#if os(iOS)
				AudioSession.instance.deactivate()
			#endif
			throw error
		}

		self.engine = engine
		inputFormat = format
		registerForNotifications()
	}

	private func stop() {
		simulatedTask?.cancel()
		simulatedTask = nil

		if let engine {
			engine.inputNode.removeTap(onBus: 0)
			engine.stop()
			self.engine = nil
			unregisterForNotifications()

			#if os(iOS)
				AudioSession.instance.deactivate()
			#endif
		}

		inputFormat = nil
		isStarted = false
	}

	func restartAfterConfigurationChange() {
		guard !subscribers.isEmpty, engine != nil else { return }

		stop()
		try? start()
		if let inputFormat { subscribers.yield(.formatChanged(inputFormat)) }
	}

	// MARK: - Simulator

	private func startSimulated() {
		guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return }
		inputFormat = format

		let frames: AVAudioFrameCount = 4_410		// 0.1s chunks, matching ~real tap cadence
		simulatedTask = Task { @MainActor [subscribers] in
			var sampleTime: AVAudioFramePosition = 0
			while !Task.isCancelled {
				if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) {
					buffer.frameLength = frames
					if let channel = buffer.floatChannelData?[0] {
						for index in 0..<Int(frames) { channel[index] = Float.random(in: -0.03...0.03) }
					}
					let time = AVAudioTime(sampleTime: sampleTime, atRate: format.sampleRate)
					subscribers.yield(.audio(CapturedAudio(buffer: buffer, time: time, level: AudioLevel(buffer: buffer))))
					sampleTime += AVAudioFramePosition(frames)
				}
				try? await Task.sleep(nanoseconds: 100_000_000)
			}
		}
	}
}

extension AudioSource {
	private func registerForNotifications() {
		guard notificationTokens.isEmpty, let engine else { return }
		let center = NotificationCenter.default

		notificationTokens.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { _ in
			Task { @MainActor in AudioSource.instance.restartAfterConfigurationChange() }
		})

		#if os(iOS)
			notificationTokens.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
				let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
				let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
				Task { @MainActor in AudioSource.instance.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw) }
			})
		#endif
	}

	private func unregisterForNotifications() {
		notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
		notificationTokens = []
	}

	#if os(iOS)
		func handleInterruption(typeRaw: UInt, optionsRaw: UInt) {
			switch AVAudioSession.InterruptionType(rawValue: typeRaw) {
			case .began:
				engine?.pause()
				subscribers.yield(.interruptionBegan)

			case .ended:
				let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
				if engine != nil { try? engine?.start() }
				subscribers.yield(.interruptionEnded(shouldResume: options.contains(.shouldResume)))

			default: break
			}
		}
	#endif
}
