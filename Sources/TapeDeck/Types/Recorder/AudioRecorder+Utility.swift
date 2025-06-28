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
	func writeBufferToDisk(buffer: AVAudioPCMBuffer) {
		do {
			try file?.write(from: buffer)
		} catch {
			print("file writing error: \(error)")
		}
	}
}
