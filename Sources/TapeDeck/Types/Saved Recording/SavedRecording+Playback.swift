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
}

extension SavedRecording {
	func buildSegmentPlaybackInfo() throws -> [SegmentPlaybackInfo] {
		var results: [SegmentPlaybackInfo] = []
		let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
		results = urls.compactMap { SegmentPlaybackInfo(url: $0) }
		
		return results.sorted()
	}
	
	@discardableResult func playSegment(index: Int) -> Bool {
		guard let segmentInfo, index < segmentInfo.count else {
			stopPlayback()
			return false
		}
		
		let info = segmentInfo[index]
		play(url: info.url(basedOn: url), duration: info.duration) {
			if !self.playSegment(index: index + 1) {
				print("All done")
			}
		}
		return true
	}
	
	func play(url: URL, duration: TimeInterval?, completion: @escaping () -> Void) {
		playbackTask?.cancel()
		
		let player = RecordingPlayer.instance.player
		let item = AVPlayerItem(url: url)
		player.replaceCurrentItem(with: item)
		player.play()
		
		if let duration {
			playbackTask = Task.detached {
				try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * duration))
				completion()
			}
		}
	}
	
	public func startPlayback() throws {
		RecordingPlayer.instance.current = self
		playbackStartedAt = Date()

		if isPackage {
			if segmentInfo	== nil { segmentInfo = try buildSegmentPlaybackInfo() }
			playSegment(index: 0)
		} else {
			play(url: url, duration: duration) {
				self.stopPlayback()
			}
		}
		objectWillChange.send()
		print("Playing: \(self.isPlaying)")
	}
	
	public func stopPlayback() {
		playbackStartedAt = nil
		playbackTask?.cancel()
		if RecordingPlayer.instance.current == self {
			RecordingPlayer.instance.player.pause()
		}
		objectWillChange.sendOnMain()
	}
}
