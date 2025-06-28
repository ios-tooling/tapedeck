//
//  AudioRecorder.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Suite
import AVFoundation
import SwiftUI


extension AudioRecorder {
	func setUpAudioSession() throws {
		#if os(iOS)
			 let audioSession = AVAudioSession.sharedInstance()
			 try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
			 try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
		#endif
	}

}
