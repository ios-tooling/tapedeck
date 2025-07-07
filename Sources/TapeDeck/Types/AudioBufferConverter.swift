//
//  AudioBufferConverter.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/7/25.
//

import Foundation
import AVFoundation

class AudioBufferConverter {
	enum AudioBufferConverterError: Swift.Error {
		case failedToCreateConverter
		case failedToCreateConversionBuffer
		case conversionFailed(NSError?)
	}
	
	private var converter: AVAudioConverter?
	func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
		let inputFormat = buffer.format
		guard inputFormat != format else { return buffer }
		
		if converter == nil || converter?.outputFormat != format {
			converter = AVAudioConverter(from: inputFormat, to: format)
			converter?.primeMethod = .none // Sacrifice quality of first samples in order to avoid any timestamp drift from source
		}
		
		guard let converter else { throw AudioBufferConverterError.failedToCreateConverter }
		
		let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
		let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
		let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
		guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
			throw AudioBufferConverterError.failedToCreateConversionBuffer
		}
		
		var nsError: NSError?
		var bufferProcessed = false
		
		let status = converter.convert(to: conversionBuffer, error: &nsError) { packetCount, inputStatusPointer in
			inputStatusPointer.pointee = bufferProcessed ? .noDataNow : .haveData
			let result = bufferProcessed ? nil : buffer
			bufferProcessed = true
			return result
		}
		
		guard status != .error else {
			throw AudioBufferConverterError.conversionFailed(nsError)
		}
		
		return conversionBuffer
	}
}
