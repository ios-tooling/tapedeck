//
//  RecordingPlayer.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation
import AVFoundation

public class RecordingPlayer: ObservableObject {
	public static let instance = RecordingPlayer()
	
	let player = AVPlayer()
	weak var playTimer: Timer?
	public var current: RecordingStore.Recording?

	public func play(_ recording: RecordingStore.Recording) {
		let item = AVPlayerItem(url: recording.url)
		
		current?.objectWillChange.send()
		current = recording
		player.replaceCurrentItem(with: item)
		player.play()
		objectWillChange.send()
		
		playTimer?.invalidate()
		if let duration = recording.duration {
			playTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { _ in
				self.stopPlaying(recording)
			})
		}
		recording.objectWillChange.send()
	}
	
	public func stopPlaying(_ recording: RecordingStore.Recording) {
		playTimer?.invalidate()
		
		if current != recording { return }
		
		current = nil
		player.pause()
		recording.objectWillChange.send()
		objectWillChange.send()
	}
	
}
