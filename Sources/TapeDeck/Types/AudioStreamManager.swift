//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 2/11/25.
//

import Foundation
import AVFoundation

class AudioStreamManager {
	 private var audioEngine: AVAudioEngine
	 private var playerNode: AVAudioPlayerNode
	 private let audioFormat: AVAudioFormat
	 private var scheduledBuffers: Int = 0
	 private let bufferCompletionQueue = DispatchQueue(label: "com.audiomanager.buffercompletion")
	 
	 init(sampleRate: Double = 44_100, channels: UInt32 = 1) {
		  audioEngine = AVAudioEngine()
		  playerNode = AVAudioPlayerNode()
		  
		  // Create standard audio format
		  audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
											 channels: AVAudioChannelCount(channels))!
		  
		  // Set up audio engine
		  audioEngine.attach(playerNode)
		  audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
		  
		  try? audioEngine.start()
		  playerNode.play()
	 }
	 
	 // Stream audio samples directly from Data
	 func streamAudioData(_ sampleData: Data) throws {
		  // Calculate number of frames (samples)
		  let sampleCount = sampleData.count / MemoryLayout<Float>.stride
		  
		  // Create buffer with the appropriate size
		  guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
														frameCapacity: AVAudioFrameCount(sampleCount)) else {
				throw NSError(domain: "AudioStreamManager", code: -1,
								 userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
		  }
		  
		  // Copy data to buffer
		  sampleData.withUnsafeBytes { rawBufferPointer in
				let floatBufferPointer = rawBufferPointer.bindMemory(to: Float.self)
				buffer.floatChannelData?[0].update(from: floatBufferPointer.baseAddress!,
															count: sampleCount)
		  }
		  buffer.frameLength = AVAudioFrameCount(sampleCount)
		  
		  // Schedule buffer for playback
		  bufferCompletionQueue.sync {
				scheduledBuffers += 1
		  }
		  
		  playerNode.scheduleBuffer(buffer) {
				self.bufferCompletionQueue.sync {
					 self.scheduledBuffers -= 1
				}
		  }
	 }
	 
	 // Pause playback
	 func pause() {
		  playerNode.pause()
	 }
	 
	 // Resume playback
	 func resume() {
		  playerNode.play()
	 }
	 
	 // Stop playback
	 func stop() {
		  playerNode.stop()
		  audioEngine.stop()
	 }
	 
	 // Check if there are buffers currently queued
	 var hasQueuedAudio: Bool {
		  bufferCompletionQueue.sync {
				return scheduledBuffers > 0
		  }
	 }
}
