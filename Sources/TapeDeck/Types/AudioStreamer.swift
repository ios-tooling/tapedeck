//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 2/11/25.
//

#if os(iOS)
import Foundation
import AVFoundation

class AudioStreamer {
	 private let audioEngine = AVAudioEngine()
	 private let audioPlayer = AVAudioPlayerNode()
	 private let format: AVAudioFormat
	 
	 init(sampleRate: Double = 44100, channels: AVAudioChannelCount = 1) {
		  // Define format
		  self.format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!

		  setupAudioEngine()
	 }
	 
	 private func setupAudioEngine() {
		  let mainMixer = audioEngine.mainMixerNode
		  audioEngine.attach(audioPlayer)
		  audioEngine.connect(audioPlayer, to: mainMixer, format: format)

		  do {
				try audioEngine.start()
				audioPlayer.play()
		  } catch {
				print("Failed to start audio engine: \(error)")
		  }
	 }

	 func streamAudioData(_ rawData: Data) {
		  let frameLength = UInt32(rawData.count) / UInt32(format.streamDescription.pointee.mBytesPerFrame)
		  
		  guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
				print("Failed to create buffer")
				return
		  }

		  buffer.frameLength = frameLength
		  rawData.withUnsafeBytes { rawBufferPointer in
				if let audioPointer = buffer.int16ChannelData {
					 memcpy(audioPointer.pointee, rawBufferPointer.baseAddress!, rawData.count)
				}
		  }
		  
		  audioPlayer.scheduleBuffer(buffer) {
			  print("Done streaming")
				// Schedule next buffer if needed
		  }
	 }
}
#endif
