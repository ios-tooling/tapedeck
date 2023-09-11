//
//  CMSampleBuffer.swift
//
//
//  Created by Ben Gottlieb on 9/10/23.
//

import Foundation
import AVFoundation
import Accelerate

extension CMSampleBuffer {
	public var samples: [Float] {
		guard let audioBuffer = CMSampleBufferGetDataBuffer(self) else {
			 return []
		}
		
		// Get the audio format description
//		guard let formatDescription = CMSampleBufferGetFormatDescription(self) else {
//			 return []
//		}
		
		// Get the number of audio channels
//		var channelInfoSize = 0
//		let channelInfo = CMAudioFormatDescriptionGetChannelLayout(formatDescription, sizeOut: &channelInfoSize)
		let channelCount = 1//channelInfo?.pointee.mNumberChannelDescriptions ?? 2
		
		// Calculate the number of samples
		let sampleCount = CMSampleBufferGetNumSamples(self)
		
		// Create an array to hold the extracted samples
		var samples = [Float](repeating: 0.0, count: sampleCount * Int(channelCount))
		
		// Copy audio data into the samples array
		let audioData = UnsafeMutablePointer<Int16>.allocate(capacity: sampleCount)
		defer {
			 audioData.deallocate()
		}
		
		CMBlockBufferCopyDataBytes(audioBuffer, atOffset: 0, dataLength: CMBlockBufferGetDataLength(audioBuffer), destination: audioData)
		
		// Convert the Int16 samples to Float
		vDSP_vflt16(audioData, 1, &samples, 1, vDSP_Length(sampleCount * Int(channelCount)))
		return samples
	}
}
