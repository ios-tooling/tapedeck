//
//  Recorder.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation
import AVFoundation
import AVKit
import Suite
import SwiftUI
import Accelerate

@MainActor public class Recorder: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate, MicrophoneListener {
	public static let instance = Recorder()
	
	public enum RecorderError: String, Error { case notImplementedOnSimulator, unableToAddOutput, unableToAddInput, noValidInputs, cantRecordOnSimulator, unableToCreateRecognitionRequest, unableToCreateRecognitionTask, noPermissions, unexpectedState }
	
	public enum State { case idle, running, paused, post }
	
	public var state = State.idle { didSet { objectWillChange.sendOnMain() }}
	public var recordingDuration: TimeInterval = 0 { didSet { objectWillChange.sendOnMain() }}
	public var activeTranscript: Transcript?
	
	let session: AVCaptureSession = AVCaptureSession()
	let queue = DispatchQueue(label: "\(Recorder.self)", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
	var audioConnection: AVCaptureConnection!
	let audioOutput = AVCaptureAudioDataOutput()
	var outputType = AudioFileType.wav16k
	var output: RecorderOutput?
	public var startedAt: Date?
	public let levelsSummary = LevelsSummary()
	var cancelBag: Set<AnyCancellable> = []
	var isPausedDueToInterruption = false
	var interruptCount = 0
	var handlers: [SamplesHandler] = []
	
	var shouldTranscribe = false
	var currentAverage: Float = 0.0
	var currentCount = 0
	var max: Double = 0
	public var samplingRate: Double { AVAudioSession.sharedInstance().sampleRate }
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
	
	func start() async throws {
		guard state == .idle else { throw RecorderError.unexpectedState }
		
		do {
			try await startRecording()
		} catch {
			logg(error: error, "Problem starting to listen")
			throw error
		}
	}
	
	public func startRecording(to output: RecorderOutput = OutputDevNull.instance, shouldTranscribe: Bool = false) async throws {
		if Gestalt.isOnSimulator { logg("CANNOT RECORD ON THE SIMULATOR"); throw RecorderError.cantRecordOnSimulator }

		guard state != .running else {
			try await Microphone.instance.setActive(self)
			return
		}
		
		try AVAudioSessionWrapper.instance.start()
		if state == .idle {
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
		await session.startRunningAsync()
		startedAt = Date()
		try await Microphone.instance.setActive(self)
		state = .running
		
		if shouldTranscribe, let url = await output.containerURL {
			activeTranscript = Transcript(forOutputURL: url)
			activeTranscript?.beginTranscribing()
		}
		
		await RecordingStore.instance.didStartRecording(to: output)
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
		try? AVAudioSessionWrapper.instance.stop()
		RecordingStore.instance.didEndRecording(to: output)
		activeTranscript?.endTranscribing()
		Microphone.instance.clearActive(self)
		if state == .idle { return }

		state = .post
		
		do {
			for handler in handlers {
				_ = try await handler.endRecording()
			}
		} catch {
			print("Error stopping the recording: \(error)")
		}
		activeTranscript?.save()
		removeSamplesHandler(output)
		session.stopRunning()
		state = .idle
		RecordingStore.instance.didFinishPostRecording(to: output)
	}
	
	public func addSamplesHandler(_ handler: SamplesHandler) {
		if !handlers.contains(where: { $0 === handler}) {
			handlers.append(handler)
		}
	}
	
	public func removeSamplesHandler(_ handler: SamplesHandler?) {
		guard let handler else { return }
		if let index = handlers.firstIndex(where: { $0 === handler }) {
			handlers.remove(at: index)
		}
	}
	
}

extension AVCaptureSession {
	func startRunningAsync() async {
		let _: Void = await withCheckedContinuation { continuation in
			self.startRunning()
			continuation.resume()
		}
	}
}
#endif
