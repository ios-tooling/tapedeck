//
//  AudioEvent.swift
//  TapeDeck
//
//	 Events delivered to AudioSource subscribers: captured audio, interruptions,
//	 and input-format changes (e.g. switching to a bluetooth mic).
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

enum AudioEvent: @unchecked Sendable {
	case audio(CapturedAudio)
	case interruptionBegan
	case interruptionEnded(shouldResume: Bool)
	case formatChanged(AVAudioFormat)
}

// the buffer is a deep copy owned by this event and never mutated after capture
final class CapturedAudio: @unchecked Sendable {
	let buffer: AVAudioPCMBuffer
	let time: AVAudioTime
	let level: AudioLevel

	init(buffer: AVAudioPCMBuffer, time: AVAudioTime, level: AudioLevel) {
		self.buffer = buffer
		self.time = time
		self.level = level
	}
}

struct AudioSubscription {
	let id: UUID
	let events: AsyncStream<AudioEvent>
	let format: AVAudioFormat?

	@MainActor func cancel() {
		AudioSource.instance.unsubscribe(id)
	}
}

// continuations are yielded to directly from the audio tap thread, so access is lock-guarded
final class AudioSubscriberRegistry: @unchecked Sendable {
	private let lock = NSLock()
	private var continuations: [UUID: AsyncStream<AudioEvent>.Continuation] = [:]

	var isEmpty: Bool {
		lock.withLock { continuations.isEmpty }
	}

	func add(id: UUID, _ continuation: AsyncStream<AudioEvent>.Continuation) {
		lock.withLock { continuations[id] = continuation }
	}

	@discardableResult func remove(_ id: UUID) -> Bool {
		let continuation = lock.withLock { continuations.removeValue(forKey: id) }
		continuation?.finish()
		return continuation != nil
	}

	func yield(_ event: AudioEvent) {
		let current = lock.withLock { Array(continuations.values) }
		current.forEach { $0.yield(event) }
	}
}
