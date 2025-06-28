//
//  TapeDeck.Recorder.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Suite
import AVFoundation
import SwiftUI

extension AVAudioPCMBuffer: @unchecked Sendable { }

class AudioRecorder: Recordable {
	private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation? = nil
	private let audioEngine: AVAudioEngine
	var playerNode: AVAudioPlayerNode?
	var file: AVAudioFile?
	var fileURL: URL?
	var isPaused = false
	var isRecording = false
	var audioStream: AsyncStream<AVAudioPCMBuffer>?
	
	init() {
		audioEngine = AVAudioEngine()
	}
	
	func start(callback: @escaping (AVAudioPCMBuffer) async throws -> Void) async throws {
		try await record()
	
		guard let audioStream else { throw RecorderError.failedToCreateAudioStream }
		for await input in try await audioStream {
			try await callback(input)
		}

	}
	
	func record() async throws {
		guard await isAuthorized else { throw RecorderError.notAuthorized }
		try setUpAudioSession()
		
		isRecording = true
		audioStream = try await buildAudioStream()
	}
	
	func pause() {
		if isPaused || !isRecording { return }
		isPaused = true
		audioEngine.pause()
	}
	
	func resume() throws {
		if !isPaused || !isRecording { return }
		isPaused = false
		try audioEngine.start()
	}
	
	func stop() {
		audioEngine.stop()
		isPaused = false
		isRecording = false
	}
	
	private func buildAudioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
		try setupAudioEngine()
		let format = audioEngine.inputNode.outputFormat(forBus: 0)
		audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
			guard let self else { return }
			writeBufferToDisk(buffer: buffer)
			outputContinuation?.yield(buffer)
		}
		
		audioEngine.prepare()
		try audioEngine.start()
		
		return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
			outputContinuation = continuation
		}
	}
	
	private func setupAudioEngine() throws {
		let inputSettings = audioEngine.inputNode.inputFormat(forBus: 0).settings
		
		if let fileURL {
			self.file = try AVAudioFile(forWriting: fileURL, settings: inputSettings)
		}
		audioEngine.inputNode.removeTap(onBus: 0)
	}
	
	var isAuthorized: Bool {
		get async {
			if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { return true }
			
			return await AVCaptureDevice.requestAccess(for: .audio)
		}
	}
	
	enum RecorderError: String, Throwable { case notAuthorized, failedToCreateAudioStream
		
	}
}
