//
//  Recorder+Capture.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation
import AVFoundation

extension CMSampleBuffer: @unchecked Sendable { }

extension Recorder {
	nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		//print("got data: \(sampleBuffer)")
		Task { await capture(output, didOutput: sampleBuffer, from: connection) }
	}
	
	@MainActor func capture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		guard state == .running, let output = self.output else { return }
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

