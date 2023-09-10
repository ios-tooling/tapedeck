//
//  Recorder.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import AVKit
import Suite
import SwiftUI
import Accelerate

public class Recorder: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate, MicrophoneListener {
	public static let instance = Recorder()
	
	enum RecorderError: String, Error { case unableToAddOutput, unableToAddInput, noValidInputs, cantRecordOnSimulator, unableToCreateRecognitionRequest, unableToCreateRecognitionTask }
	
	public enum State { case idle, running, paused, post }
	
	public var state = State.idle { didSet { objectWillChange.sendOnMain() }}
	public var recordingDuration: TimeInterval = 0 { didSet { objectWillChange.sendOnMain() }}
	public var activeTranscript: Transcript?
	
	let session: AVCaptureSession = AVCaptureSession()
	let queue = DispatchQueue(label: "\(Recorder.self)", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
	var audioConnection: AVCaptureConnection!
	let audioOutput = AVCaptureAudioDataOutput()
	var outputType = AudioFileType.wav
	var output: RecorderOutput?
	public var startedAt: Date?
	public let levelsSummary = LevelsSummary()
	var cancelBag: Set<AnyCancellable> = []
	var isPausedDueToInterruption = false
	var interruptCount = 0
	var handlers: [SamplesHandler] = []
	
	var currentAverage: Float = 0.0
	var currentCount = 0
	var max: Double = 0
	var samplingRate = 44_100
	var totalSamplesReceived: Int64 = 0

	override init() {
		super.init()
		setupInterruptions()
	}
	
	public var isRecording: Bool { state == .running || state == .paused }
	
	public var wallClockDuration: TimeInterval {
		guard let startedAt else { return 0 }
		return Date().timeIntervalSince(startedAt)
	}
	
	public var duration: TimeInterval {
		return Double(totalSamplesReceived) / Double(samplingRate)
	}
	
	func start() async throws -> Bool {
		guard state == .idle else { return false }
		
		do {
			try await startRecording()
			return true
		} catch {
			logg(error: error, "Problem starting to listen")
		}
		return false
	}
	
	public func startRecording(to output: RecorderOutput = OutputDevNull.instance) async throws {
		if Gestalt.isOnSimulator { logg("CANNOT RECORD ON THE SIMULATOR"); throw RecorderError.cantRecordOnSimulator }

		guard state != .running else {
			try await Microphone.instance.setActive(self)
			return
		}
		
		try AVAudioSessionWrapper.instance.start()
		if state == .idle {
			startedAt = Date()
			self.output = output
			addSamplesHandler(output)
			try await output.prepareToRecord()
		}
		
		if session.outputs.isEmpty {
			audioOutput.setSampleBufferDelegate(self, queue: queue)
			guard session.canAddOutput(audioOutput) else { throw RecorderError.unableToAddOutput }
			
			session.addOutput(audioOutput)
		}
		
		if session.inputs.isEmpty {
			guard let audioDevice = AVCaptureDevice.default(for: .audio) else { throw RecorderError.noValidInputs}
			let audioIn = try AVCaptureDeviceInput(device: audioDevice)
			
			session.addInput(audioIn)
		}

		audioConnection = audioOutput.connection(with: .audio)
		session.startRunning()
		try await Microphone.instance.setActive(self)
		state = .running
		
		activeTranscript = Transcript()
		activeTranscript?.beginTranscribing()

		RecordingStore.instance.didStartRecording(to: output)
	}
	
	@MainActor public func pause() async throws {
		guard state == .running else { return }
		
		state = .paused
		session.stopRunning()
	}
	
	@MainActor public func resume() {
		guard state == .paused, let output else { return }
		Task.detached {
			try await self.startRecording(to: output)
		}
	}
	
	@MainActor public func stop() async throws {
		activeTranscript?.endTranscribing()
		activeTranscript?.save(forOutputURL: output?.containerURL)
		Microphone.instance.clearActive(self)
		if state == .idle { return }

		try? AVAudioSessionWrapper.instance.stop()
		RecordingStore.instance.didEndRecording(to: output)
		state = .post
		removeSamplesHandler(output)

		do {
			_ = try await output?.endRecording()
			session.stopRunning()
		} catch {
			session.stopRunning()
			throw error
		}
		state = .idle
		RecordingStore.instance.didFinishPostRecording(to: output)
	}
	
	public func addSamplesHandler(_ handler: SamplesHandler) {
		if !handlers.contains(where: { $0 === handler}) {
			handlers.append(handler)
		}
	}
	
	public func removeSamplesHandler(_ handler: SamplesHandler?) {
		if let index = handlers.firstIndex(where: { $0 === output }) {
			handlers.remove(at: index)
		}
	}
	
}
