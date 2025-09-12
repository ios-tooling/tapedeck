//
//  TapeDeck.Recorder.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Suite
import AVFoundation
import SwiftUI

extension AVAudioPCMBuffer: @retroactive @unchecked Sendable { }
typealias AudioContinuation = AsyncStream<AVAudioPCMBuffer>.Continuation

@Observable @MainActor class AudioRecorder: Recordable {
	private var outputContinuation: AudioContinuation? = nil
	private let audioEngine: AVAudioEngine
	var playerNode: AVAudioPlayerNode?
	var file: AVAudioFile?
	var fileURL: URL?
	var isPaused = false
	var isRecording = false
	var audioStream: AsyncStream<AVAudioPCMBuffer>?
	
	var state: RecordableState {
		if isPaused { return .paused }
		if isRecording { return .recording }
		return .idle
	}
	
	init() {
		audioEngine = AVAudioEngine()
	}
	
	func start(callback: @escaping (AVAudioPCMBuffer) async throws -> Void) async throws {
		try await record()
	
		guard let audioStream else { throw RecorderError.failedToCreateAudioStream }
		for await input in audioStream {
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
		
		setupInputNode(using: format, on: audioEngine.inputNode, file: file)
		audioEngine.prepare()
		try audioEngine.start()
		
		return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
			outputContinuation = continuation
		}
	}
	
	nonisolated func setupInputNode(using  format: AVAudioFormat, on inputNode: AVAudioInputNode, file: AVAudioFile?) {
		inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, time in
			file?.writeBufferToDisk(buffer: buffer)
			Task {
				let continuation = await self.outputContinuation
				continuation?.yield(buffer)
			}
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
