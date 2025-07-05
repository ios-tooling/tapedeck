//
//  AudioRecorder.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Suite
import AVFoundation
import SwiftUI

extension AVAudioFile {
	nonisolated func writeBufferToDisk(buffer: AVAudioPCMBuffer) {
		do {
			try write(from: buffer)
		} catch {
			print("file writing error: \(error)")
		}
	}
}

extension AudioRecorder {
	nonisolated func writeBufferToDisk(buffer: AVAudioPCMBuffer, in file: AVAudioFile?) {
		file?.writeBufferToDisk(buffer: buffer)
	}
}
