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
	
	public var current: SavedRecording? { willSet {
		if let current, current.state == .playing { current.stopPlayback() }
	}}
	
	var player = AVPlayer()
	var queuePlayer = AVQueuePlayer()
	weak var playTimer: Timer?
}
