//
//  RawPlayback.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 2/23/25.
//

import Foundation
import AVFoundation

@MainActor public class RawPlayback {
	public static let instance = RawPlayback()
	
	private var audioEngine: AVAudioEngine
	private var playerNode: AVAudioPlayerNode
	private var audioFormat: AVAudioFormat
	var isPlaying = false
	
	var interruptionToken: Any?
	
	private init(sampleRate: Double = 44100) {
		self.audioEngine = AVAudioEngine()
		self.playerNode = AVAudioPlayerNode()
		
		// Define the audio format for playback (Float32)
		self.audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
													sampleRate: sampleRate,
													channels: 1,
													interleaved: false)!
		
		audioEngine.attach(playerNode)
		audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)

		interruptionToken = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
			guard let engine = note.object as? AVAudioEngine else { return }
			Task { self?.handleInterruption(from: engine)}
		}
		
		start()
	}
	
	func handleInterruption(from engine: AVAudioEngine) {
		print("Audio INterrupt")
		if engine == audioEngine {
			stop()
		}
	}
	
	public func start() {
		if isPlaying { return }
		do {
			try audioEngine.start()
			isPlaying = true
		} catch {
			print("Error starting AVAudioEngine: \(error.localizedDescription)")
		}
	}
	
	public func stop() {
		if !isPlaying { return }
		isPlaying = false
		audioEngine.stop()
	}
	
	public func playAudio(from url: URL) {
		guard let data = try? Data(contentsOf: url) else { return }
		
		playAudio(from: data)
	}
	
	public func playAudio(from rawInt16Data: Data) {
		start()
		let int16Count = rawInt16Data.count / MemoryLayout<Int16>.size
		let frameLength = UInt32(int16Count)
		
		guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameLength) else { return }
		buffer.frameLength = frameLength
		
		let floatBufferPointer = buffer.floatChannelData![0]
		
		// Convert Int16 samples to Float32 samples
		rawInt16Data.withUnsafeBytes { (int16Pointer: UnsafeRawBufferPointer) in
			let int16Samples = int16Pointer.bindMemory(to: Int16.self)
			for i in 0..<int16Count {
				floatBufferPointer[i] = Float(int16Samples[i]) / Float(Int16.max)  // Normalize to [-1, 1]
			}
		}
		
		playerNode.scheduleBuffer(buffer, completionHandler: nil)
		playerNode.play()
	}
}
