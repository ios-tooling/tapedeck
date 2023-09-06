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
	
	public var current: SavedRecording? { didSet {
		current?.stopPlayback()
		
	}}
	
	let player = AVPlayer()
	weak var playTimer: Timer?
}
