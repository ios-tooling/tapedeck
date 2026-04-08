//
//  AudioSampleConverter.swift
//  
//
//  Created by Ben Gottlieb on 9/10/23.
//

#if os(iOS)
import Foundation
import AVFoundation

// based off of https://stackoverflow.com/questions/42972276/ios-convert-audio-sample-rate-from-16-khz-to-8-khz

@AudioActor class AudioSampleConverter {
	static let instance = AudioSampleConverter()
	
	var audioConverter: AudioConverterRef?
	var isSetup = false

	func convert(samples: [Float]) -> [Float]? {
		if !buildConverter() { return nil }
		
		var samplesCopy = samples
		samplesCopy.withUnsafeMutableBytes { inBufferPointer in
			var inBuffer = AudioBuffer()
			var inBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: inBuffer)
			
			inBuffer.mNumberChannels = 1
			inBuffer.mDataByteSize = UInt32(samples.count * 2)
			inBuffer.mData = inBufferPointer.baseAddress
			
			var outBuffer = AudioBuffer()
			var outBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: outBuffer)
			
			outBuffer.mNumberChannels = 1
			outBuffer.mDataByteSize = UInt32(samples.count * 2)

			let ptr = UnsafeMutableRawPointer.allocate(byteCount: samples.count * 2, alignment: 2)
			defer { ptr.deallocate() }
			outBuffer.mData = ptr

			var inputSize = UInt32(samples.count)
			let result = AudioConverterFillComplexBuffer(audioConverter!, { converter, packages, dataDescription, data, user in 
				return 0
			}, &inBufferList, &inputSize, &outBufferList, nil)
			print(result)
		}

		return []
	}
	
	func buildConverter() -> Bool {
		if audioConverter != nil { return true }
		
		if !isSetup { return false }
		isSetup = true
		var raw44kDescription = AudioStreamBasicDescription()
		var raw16kDescription = AudioStreamBasicDescription()

		raw44kDescription.mSampleRate = 44_100
		raw44kDescription.mFormatID = kAudioFormatLinearPCM
		raw44kDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian
		raw44kDescription.mBitsPerChannel = 16
		raw44kDescription.mChannelsPerFrame = 1
		raw44kDescription.mBytesPerFrame = 2 * raw44kDescription.mChannelsPerFrame
		raw44kDescription.mFramesPerPacket = 1
		raw44kDescription.mBytesPerPacket = raw44kDescription.mBytesPerFrame * raw44kDescription.mFramesPerPacket

		raw16kDescription.mSampleRate = 16000.0
		raw16kDescription.mFormatID = kAudioFormatLinearPCM
		raw16kDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian
		raw16kDescription.mBitsPerChannel = 8 * 2
		raw16kDescription.mChannelsPerFrame = 1
		raw16kDescription.mBytesPerFrame = 2 * raw16kDescription.mChannelsPerFrame
		raw16kDescription.mFramesPerPacket = 1
		raw16kDescription.mBytesPerPacket = raw16kDescription.mBytesPerFrame * raw16kDescription.mFramesPerPacket

		let status = AudioConverterNew(&raw44kDescription, &raw16kDescription, &audioConverter)
		if status == 0 { return true }
		audioConverter = nil
		return false

	}
}
#endif
