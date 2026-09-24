//
//  AudioTap.swift
//  TapeDeck
//
//	 Raw captured buffers off the shared AudioSource, for consumers that process
//	 audio themselves (speech models, custom analysis). Runs alongside recording
//	 and metering. Pass a bufferLimit when the consumer can fall behind: once that
//	 many buffers are queued the oldest are dropped, and droppedFrames counts them,
//	 so memory stays bounded instead of growing for as long as the consumer lags.
//
//  Created by Ben Gottlieb on 9/24/26.
//

import AVFoundation
import Synchronization

@MainActor public final class AudioTap {
	// buffers are deep copies owned by the event and never mutated after capture
	public enum Event: @unchecked Sendable {
		case audio(AVAudioPCMBuffer, AVAudioTime)
		case interruptionBegan
		case interruptionEnded(shouldResume: Bool)
		case formatChanged(AVAudioFormat)
	}

	// audio-session category/mode used while the mic runs; set before starting
	public static var sessionConfiguration: AudioSessionConfiguration {
		get { AudioSource.instance.configuration }
		set { AudioSource.instance.configuration = newValue }
	}

	public let events: AsyncStream<Event>
	public let format: AVAudioFormat?
	private let subscription: AudioSubscription
	private let dropped: DroppedFrames

	// frames discarded because the consumer fell more than bufferLimit buffers behind
	public nonisolated var droppedFrames: Int { dropped.count }

	public static func start(bufferLimit: Int? = nil) async throws -> AudioTap {
		let subscription = try await AudioSource.instance.subscribe()
		return AudioTap(subscription: subscription, bufferLimit: bufferLimit)
	}

	private init(subscription: AudioSubscription, bufferLimit: Int?) {
		let policy: AsyncStream<Event>.Continuation.BufferingPolicy = bufferLimit.map { .bufferingNewest($0) } ?? .unbounded
		let (events, continuation) = AsyncStream.makeStream(of: Event.self, bufferingPolicy: policy)
		let dropped = DroppedFrames()

		self.events = events
		self.format = subscription.format
		self.subscription = subscription
		self.dropped = dropped

		// relays the source's unbounded queue into the bounded one; this loop does no
		// work, so the source queue drains as fast as buffers arrive
		Task.detached { [source = subscription.events] in
			for await event in source {
				if case .dropped(.audio(let buffer, _)) = continuation.yield(Event(event)) { dropped.add(Int(buffer.frameLength)) }
			}
			continuation.finish()
		}
		continuation.onTermination = { _ in
			Task { @MainActor in subscription.cancel() }
		}
	}

	public func stop() {
		subscription.cancel()
	}
}

private extension AudioTap.Event {
	init(_ event: AudioEvent) {
		switch event {
		case .audio(let captured): self = .audio(captured.buffer, captured.time)
		case .interruptionBegan: self = .interruptionBegan
		case .interruptionEnded(let shouldResume): self = .interruptionEnded(shouldResume: shouldResume)
		case .formatChanged(let format): self = .formatChanged(format)
		}
	}
}

private final class DroppedFrames: Sendable {
	private let frames = Mutex(0)

	var count: Int { frames.withLock { $0 } }
	func add(_ count: Int) { frames.withLock { $0 += count } }
}
