//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/6/23.
//

import Foundation
import AVFoundation

struct SegmentPlaybackInfo: Comparable {
	let duration: TimeInterval
	let filename: String
	
	func url(basedOn base: URL) -> URL { base.appendingPathComponent(filename) }
	static func <(lhs: Self, rhs: Self) -> Bool {
		lhs.filename < rhs.filename
	}
	
	init?(url: URL) {
		filename = url.lastPathComponent
		if let seconds = url.audioDuration {
			self.duration = seconds
		} else {
			return nil
		}
	}
	
	func playerItem(basedOn base: URL) -> AVPlayerItem { AVPlayerItem(url: url(basedOn: base)) }
}

extension SavedRecording {
	func buildSegmentPlaybackInfo() throws -> [SegmentPlaybackInfo] {
		var results: [SegmentPlaybackInfo] = []
		let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
		results = urls.compactMap { SegmentPlaybackInfo(url: $0) }
		
		return results.sorted()
	}
	
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
	
	func playSegments(segments: [SegmentPlaybackInfo], completion: @escaping () -> Void) {
		RecordingPlayer.instance.queuePlayer = AVQueuePlayer(items: segments.map { $0.playerItem(basedOn: url) })
		RecordingPlayer.instance.player.pause()
		RecordingPlayer.instance.queuePlayer.play()

		if let duration {
			playbackTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in completion() }
		}
	}
	
	public func startPlayback() throws {
		RecordingPlayer.instance.current = self
		playbackStartedAt = Date()

		if isPackage {
			guard let segmentInfo else { return }
			playSegments(segments: segmentInfo) {
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
		playbackStartedAt = nil
		playbackTimer?.invalidate()
		
		if RecordingPlayer.instance.current == self {
			RecordingPlayer.instance.queuePlayer.pause()
			RecordingPlayer.instance.player.pause()
		}
		objectWillChange.sendOnMain()
	}
}
