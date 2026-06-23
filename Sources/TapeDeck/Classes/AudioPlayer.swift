//
//  AudioPlayer.swift
//  TapeDeck
//
//	 Plays single files, segmented packages, or an arbitrary timeline of timed
//	 audio files (queued seamlessly), with observable progress. Supports starting
//	 at an offset, an optional end offset (window playback), and rewinding to the
//	 start when playback finishes. One thing plays at a time per instance.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

@MainActor @Observable public class AudioPlayer {
	public static let instance = AudioPlayer()

	// one audio file positioned on a shared timeline
	public struct TimelineItem: Sendable, Equatable {
		public let url: URL
		public let start: TimeInterval
		public let duration: TimeInterval

		public init(url: URL, start: TimeInterval, duration: TimeInterval) {
			self.url = url
			self.start = start
			self.duration = duration
		}

		var end: TimeInterval { start + duration }
	}

	public private(set) var nowPlaying: Recording?
	public private(set) var isPlaying = false
	public private(set) var currentTime: TimeInterval = 0
	public private(set) var duration: TimeInterval = 0

	public var progress: Double { duration > 0 ? min(currentTime / duration, 1) : 0 }

	private let player = AVQueuePlayer()
	private var timeObserver: Any?
	private var endObserver: (any NSObjectProtocol)?

	private var items: [TimelineItem] = []
	private var queuedIndex = 0					// index of the item currently at the front of the queue
	private var startOffset: TimeInterval = 0
	private var endOffset: TimeInterval?
	private var rewindOnFinish = false

	public init() {}

	// MARK: - Loading

	// Prepares a timeline positioned at `startOffset` WITHOUT starting playback.
	// `endOffset` bounds playback to a window; `rewindToStartOnFinish` returns the
	// playhead to `startOffset` when the window/timeline finishes.
	public func setTimeline(_ timeline: [TimelineItem], startOffset: TimeInterval = 0, endOffset: TimeInterval? = nil, rewindToStartOnFinish: Bool = false) async {
		stop()
		guard !timeline.isEmpty else { return }

		items = timeline.sorted { $0.start < $1.start }
		duration = items.map(\.end).max() ?? 0
		self.endOffset = endOffset.map { min(max(0, $0), duration) }
		self.startOffset = min(max(0, startOffset), self.endOffset ?? duration)
		rewindOnFinish = rewindToStartOnFinish
		addTimeObserver()
		await seek(to: self.startOffset)
	}

	public func play(_ file: AudioFile) async throws {
		guard file.exists else { throw TapeDeckError.fileNotFound(file.url) }
		let length = (try? await file.duration()) ?? 0
		await setTimeline([TimelineItem(url: file.url, start: 0, duration: length)])
		nowPlaying = .file(file)
		play()
	}

	public func play(_ package: RecordingPackage) async throws {
		guard package.exists else { throw TapeDeckError.fileNotFound(package.url) }
		let chunks = (try? package.loadManifest())?.chunks ?? []
		let timeline = chunks.map { TimelineItem(url: package.url.appendingPathComponent($0.filename), start: $0.start, duration: $0.duration) }
		await setTimeline(timeline)
		nowPlaying = .package(package)
		play()
	}

	// MARK: - Transport

	public func play() {
		guard !items.isEmpty, !isPlaying else { return }
		activatePlaybackSession()
		isPlaying = true

		// restart from the window start if the playhead is sitting at the finished end
		if currentTime >= (endOffset ?? duration) {
			Task { await seek(to: startOffset); player.play() }
		} else {
			player.play()
		}
	}

	public func pause() {
		guard isPlaying else { return }
		player.pause()
		isPlaying = false
	}

	public func stop() {
		removeObservers()
		player.pause()
		player.removeAllItems()
		nowPlaying = nil
		isPlaying = false
		currentTime = 0
		duration = 0
		items = []
		queuedIndex = 0
		startOffset = 0
		endOffset = nil
		rewindOnFinish = false
	}

	// Seeks to a timeline offset. `tolerance` loosens accuracy for responsive scrubbing.
	public func seek(to time: TimeInterval, tolerance: CMTime = .zero) async {
		let upper = endOffset ?? duration
		let target = max(0, min(time, upper))
		guard let index = items.firstIndex(where: { target < $0.end }) ?? items.indices.last else { return }
		currentTime = target
		let local = CMTime(seconds: max(0, target - items[index].start), preferredTimescale: 600)

		if index == queuedIndex, player.currentItem != nil {
			await player.seek(to: local, toleranceBefore: tolerance, toleranceAfter: tolerance)
		} else {
			player.removeAllItems()
			enqueueItems(startingAt: index)
			await player.seek(to: local, toleranceBefore: tolerance, toleranceAfter: tolerance)
		}
		if isPlaying { player.play() }
	}

	// MARK: - Queue

	private func enqueueItems(startingAt index: Int) {
		queuedIndex = index
		for item in items[index...] {
			player.insert(AVPlayerItem(url: item.url), after: nil)
		}
		if let last = player.items().last { observeEnd(of: last) }
	}

	private func activatePlaybackSession() {
		#if os(iOS)
		try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
		try? AVAudioSession.sharedInstance().setActive(true)
		#endif
	}

	// MARK: - Progress

	private func updateCurrentTime() {
		guard let item = player.currentItem else {
			finish()											// queue ran dry
			return
		}

		let itemTime = max(0, item.currentTime().seconds)
		if let url = (item.asset as? AVURLAsset)?.url, let match = items.first(where: { $0.url == url }) {
			queuedIndex = items.firstIndex(of: match) ?? queuedIndex
			currentTime = match.start + itemTime
		} else {
			currentTime = itemTime
		}

		if let endOffset, currentTime >= endOffset { finish() }
	}

	private func finish() {
		player.pause()
		player.removeAllItems()
		isPlaying = false
		if rewindOnFinish {
			currentTime = startOffset
			enqueueItems(startingAt: items.firstIndex(where: { startOffset < $0.end }) ?? 0)
			Task { await player.seek(to: CMTime(seconds: max(0, startOffset - items[queuedIndex].start), preferredTimescale: 600)) }
		} else {
			currentTime = endOffset ?? duration
		}
	}

	// MARK: - Observers

	private func addTimeObserver() {
		removeObservers()
		timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] _ in
			Task { @MainActor in self?.updateCurrentTime() }
		}
	}

	// The periodic observer stops firing once playback ends, so watch the final item
	// finishing to notice the queue ran dry. Scoped to that item so nothing crosses an
	// isolation boundary from the notification.
	private func observeEnd(of item: AVPlayerItem) {
		if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
		endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
			MainActor.assumeIsolated { self?.finish() }
		}
	}

	private func removeObservers() {
		if let timeObserver { player.removeTimeObserver(timeObserver) }
		timeObserver = nil
		if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
		endObserver = nil
	}
}
