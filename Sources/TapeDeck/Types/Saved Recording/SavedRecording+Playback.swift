//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/6/23.
//

import Foundation
import AVFoundation

extension SavedRecording {
	public func startPlayback() {
		let item = AVPlayerItem(url: url)
		let player = RecordingPlayer.instance.player
		
		RecordingPlayer.instance.current = self
		player.replaceCurrentItem(with: item)
		player.play()
		objectWillChange.send()
		
		RecordingPlayer.instance.playTimer?.invalidate()
		if let duration = duration {
			RecordingPlayer.instance.playTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { _ in
				self.stopPlayback()
			})
		}
		objectWillChange.send()
	}
	
	public func stopPlayback() {
		RecordingPlayer.instance.playTimer?.invalidate()
		
		RecordingPlayer.instance.player.pause()
		objectWillChange.send()
	}
}
