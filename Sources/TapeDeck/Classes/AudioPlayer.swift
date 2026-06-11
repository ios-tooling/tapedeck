//
//  AudioPlayer.swift
//  TapeDeck
//
//	 Plays single audio files and segmented packages (chunks queued seamlessly),
//	 with observable progress. One thing plays at a time.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

@MainActor @Observable public class AudioPlayer {
	public static let instance = AudioPlayer()

	public private(set) var nowPlaying: Recording?
	public private(set) var isPlaying = false
	public private(set) var currentTime: TimeInterval = 0
	public private(set) var duration: TimeInterval = 0

	public var progress: Double { duration > 0 ? min(currentTime / duration, 1) : 0 }

	private let player = AVQueuePlayer()
	private var timeObserver: Any?
	private var chunks: [RecordingPackage.Manifest.Chunk] = []
	private var packageURL: URL?

	public func play(_ file: AudioFile) async throws {
		stop()
		guard file.exists else { throw TapeDeckError.fileNotFound(file.url) }

		nowPlaying = .file(file)
		duration = (try? await file.duration()) ?? 0
		player.insert(AVPlayerItem(url: file.url), after: nil)
		beginPlayback()
	}

	public func play(_ package: RecordingPackage) async throws {
		stop()
		guard package.exists else { throw TapeDeckError.fileNotFound(package.url) }

		nowPlaying = .package(package)
		chunks = (try? package.loadManifest())?.chunks ?? []
		packageURL = package.url
		duration = package.duration
		enqueueChunks(startingAt: 0)
		beginPlayback()
	}

	public func pause() {
		guard isPlaying else { return }
		player.pause()
		isPlaying = false
	}

	public func resume() {
		guard nowPlaying != nil, !isPlaying else { return }
		player.play()
		isPlaying = true
	}

	public func stop() {
		removeTimeObserver()
		player.pause()
		player.removeAllItems()
		nowPlaying = nil
		isPlaying = false
		currentTime = 0
		duration = 0
		chunks = []
		packageURL = nil
	}

	public func seek(to time: TimeInterval) async {
		let target = max(0, min(time, duration))

		if chunks.isEmpty {
			await player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
		} else if let index = chunks.firstIndex(where: { $0.start + $0.duration > target }) {
			// AVQueuePlayer can't seek into consumed items, so rebuild the queue from the target chunk
			player.removeAllItems()
			enqueueChunks(startingAt: index)
			await player.seek(to: CMTime(seconds: target - chunks[index].start, preferredTimescale: 600))
			if isPlaying { player.play() }
		}
		updateCurrentTime()
	}

	private func enqueueChunks(startingAt index: Int) {
		guard let packageURL else { return }
		for chunk in chunks[index...] {
			player.insert(AVPlayerItem(url: packageURL.appendingPathComponent(chunk.filename)), after: nil)
		}
	}

	private func beginPlayback() {
		addTimeObserver()
		player.play()
		isPlaying = true
	}

	private func updateCurrentTime() {
		guard let item = player.currentItem else {
			if isPlaying { stop() }											// queue ran dry: playback finished
			return
		}

		let itemTime = max(0, item.currentTime().seconds)
		if chunks.isEmpty {
			currentTime = itemTime
		} else if let url = (item.asset as? AVURLAsset)?.url, let chunk = chunks.first(where: { $0.filename == url.lastPathComponent }) {
			currentTime = chunk.start + itemTime
		}
	}

	private func addTimeObserver() {
		timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { _ in
			Task { @MainActor in AudioPlayer.instance.updateCurrentTime() }
		}
	}

	private func removeTimeObserver() {
		if let timeObserver { player.removeTimeObserver(timeObserver) }
		timeObserver = nil
	}
}
