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

	private(set) var inputFormat: AVAudioFormat?
	var isRunning: Bool { engine != nil }

	private var engine: AVAudioEngine?
	private let subscribers = AudioSubscriberRegistry()
	private var notificationTokens: [any NSObjectProtocol] = []

	func subscribe() async throws -> AudioSubscription {
		guard await Permissions.requestMicrophone() else { throw TapeDeckError.microphonePermissionDenied }

		let id = UUID()
		let stream = AsyncStream<AudioEvent> { continuation in
			subscribers.add(id: id, continuation)
			continuation.onTermination = { _ in
				Task { @MainActor in AudioSource.instance.unsubscribe(id) }
			}
		}

		if engine == nil { try start() }
		return AudioSubscription(id: id, events: stream, format: inputFormat)
	}

	func unsubscribe(_ id: UUID) {
		guard subscribers.remove(id) else { return }
		if subscribers.isEmpty { stop() }
	}

	private func start() throws {
		#if os(iOS)
			try AudioSession.instance.activate()
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
		guard let engine else { return }

		engine.inputNode.removeTap(onBus: 0)
		engine.stop()
		self.engine = nil
		inputFormat = nil
		unregisterForNotifications()

		#if os(iOS)
			AudioSession.instance.deactivate()
		#endif
	}

	func restartAfterConfigurationChange() {
		guard !subscribers.isEmpty, engine != nil else { return }

		stop()
		try? start()
		if let inputFormat { subscribers.yield(.formatChanged(inputFormat)) }
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
