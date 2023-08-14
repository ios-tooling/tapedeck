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
	
	enum RecorderError: Error { case unableToAddOutput, unableToAddInput, noValidInputs, cantRecordOnSimulator }
	
	public var isRunning = false { didSet { objectWillChange.sendOnMain() }}
	public var recordingDuration: TimeInterval = 0 { didSet { objectWillChange.sendOnMain() }}
	
	let session: AVCaptureSession = AVCaptureSession()
	let queue = DispatchQueue(label: "\(Recorder.self)", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
	var audioConnection: AVCaptureConnection!
	let audioOutput = AVCaptureAudioDataOutput()
	var outputType = AudioFileType.wav
	var output: RecorderOutput?
	public let levelsSummary = LevelsSummary()

	func start() async throws -> Bool {
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

		guard !isRunning else {
			try await Microphone.instance.setActive(self)
			return
		}
		
		self.output = output
		try await output.prepareToRecord()

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
		self.session.startRunning()
		try await Microphone.instance.setActive(self)
		isRunning = true
		print("Now running")
	}
	
	@MainActor public func stop() async throws {
		Microphone.instance.clearActive(self)
		if !isRunning { return }
		
		isRunning = false
		do {
			_ = try await output?.endRecording()
			session.stopRunning()
		} catch {
			session.stopRunning()
			throw error
		}
	}
	
	var currentAverage: Float = 0.0
	var currentCount = 0
	var max: Double = 0
}

extension CMSampleBuffer: @unchecked Sendable { }

extension Recorder {
	nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		print("got data: \(sampleBuffer)")
		Task { await capture(output, didOutput: sampleBuffer, from: connection) }
	}
	
	@MainActor func capture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		guard isRunning, let output = self.output else { return }
		output.handle(buffer: sampleBuffer)
		let threshold = 44100 / 30
		
		if let avg = sampleBuffer.dataBuffer?.average {
			currentAverage += avg * Float(sampleBuffer.numSamples)
			currentCount += sampleBuffer.numSamples
			
			levelsSummary.add(samples: sampleBuffer.dataBuffer?.sampleInt16s ?? [])
			if currentCount > threshold {
				let cumeAverage = Double(currentAverage / Float(currentCount))
				let db = cumeAverage
				let calibrated = db - Volume.baselineDBAdjustment
				
				let reported = Volume(detectedRoomVolume: connection.audioChannels.last?.averagePowerLevel.double)
				let environmentDBAvgSPL = reported ?? Volume.dB(calibrated)
				if environmentDBAvgSPL.db > max {
					max = environmentDBAvgSPL.db
				}
				
				Microphone.instance.history.record(volume: environmentDBAvgSPL)
				currentAverage = 0
				currentCount = 0
			}
		}
	}
}

extension Float {
	var double: Double { Double(self) }
}
