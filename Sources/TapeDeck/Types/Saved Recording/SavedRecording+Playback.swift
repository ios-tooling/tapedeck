//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/6/23.
//

#if os(iOS)
import Foundation
import AVFoundation

struct SegmentPlaybackInfo: Comparable {
	let duration: TimeInterval
	let filename: String
	
	func url(basedOn base: URL) -> URL { base.appendingPathComponent(filename) }
	static func <(lhs: Self, rhs: Self) -> Bool {
		lhs.filename < rhs.filename
	}
	
	private init(duration: TimeInterval, filename: String) {
		self.duration = duration
		self.filename = filename
	}
	
	static func info(from url: URL) async -> Self? {
		let filename = url.lastPathComponent
		if let seconds = try? await url.audioDuration {
			return SegmentPlaybackInfo(duration: seconds, filename: filename)
		} else {
			return nil
		}
	}
	
	func playerItem(basedOn base: URL) -> AVPlayerItem { AVPlayerItem(url: url(basedOn: base)) }
}

extension SavedRecording {
	func play(url: URL, duration: TimeInterval?, completion: @escaping () -> Void) {
		playbackTimer?.invalidate()
		
		let player = RecordingPlayer.instance.player
		let item = AVPlayerItem(url: url)
		player.replaceCurrentItem(with: item)
		player.play()
		
		if let duration {
			playbackTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in completion() }
		}
	}
	
	func playSegments(segments: [Transcript.Segment], completion: @escaping () -> Void) {
		RecordingPlayer.instance.player.pause()
		RecordingPlayer.instance.queuePlayer.pause()
		
		let items = segments.map { $0.playerItem(basedOn: url) }
		RecordingPlayer.instance.queuePlayer = AVQueuePlayer(items: items)
		RecordingPlayer.instance.queuePlayer.play()

		if let duration {
			playbackTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in completion() }
		}
	}
	
	public func startPlayback() throws {
		if state != .ready { return }
		RecordingPlayer.instance.current = self
		playbackStartedAt = Date()

		state = .playing
		if isPackage {
			guard !transcript.isEmpty else { return }
			playSegments(segments: transcript.segments) {
				self.stopPlayback()
			}
		} else {
			play(url: url, duration: duration) {
				self.stopPlayback()
			}
		}
		objectWillChange.send()
	}
	
	public func stopPlayback() {
		if state != .playing { return }
		state = .ready
		playbackStartedAt = nil
		playbackTimer?.invalidate()
		
		if RecordingPlayer.instance.current == self {
			RecordingPlayer.instance.queuePlayer.pause()
			RecordingPlayer.instance.player.pause()
		}
		objectWillChange.sendOnMain()
	}
}
#endif
