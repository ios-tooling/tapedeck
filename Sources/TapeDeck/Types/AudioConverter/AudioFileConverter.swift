//
//  AudioFileConverter.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Combine
import Suite

@AudioActor public class AudioFileConverter: NSObject {
	enum ConversionError: Error { case noInput, outputTypeNotSupported, failedtoCreateExportSesssion, failedtoCreateExportFile, failedtoCreateSourceFile, OSError(Int32) }
	
	private var sources: [URL]
	private var startOffset: TimeInterval?
	private var endDuration: TimeInterval?
	private var outputFormat: Recorder.AudioFileType
	private var destination: URL
	private var deleteSource: Bool = false
	private var progress: Binding<Double>?
	
	public static var deleteConversionArtifacts = true
	
	public init(source: URL, to output: Recorder.AudioFileType, at dest: URL, deletingSource: Bool? = nil, progress: Binding<Double>?) {
		sources = [source]
		outputFormat = output
		destination = dest
		deleteSource = deletingSource ?? Self.deleteConversionArtifacts
		self.progress = progress
		super.init()
		self.addAsObserver(of: AVAudioSession.interruptionNotification, selector: #selector(interruptionReceived))
	}
	
	public init(sources: [URL], start: TimeInterval?, endChunkDuration: TimeInterval?, to output: Recorder.AudioFileType, at dest: URL, deletingSource: Bool? = nil, progress: Binding<Double>?) {
		self.sources = sources
		outputFormat = output
		destination = dest
		deleteSource = deletingSource ?? Self.deleteConversionArtifacts
		endDuration = endChunkDuration
		startOffset = start
		self.progress = progress
		super.init()
		self.addAsObserver(of: AVAudioSession.interruptionNotification, selector: #selector(interruptionReceived))
	}
	
	@objc func interruptionReceived(note: Notification) {
		logg(error: nil, "interrupted")
	}
	
	@discardableResult public func convert() async throws -> URL {
		for source in sources {
			guard let exportSession = AVAssetExportSession(asset: AVAsset(url: source), presetName: AVAssetExportPresetAppleM4A) else {
				throw ConversionError.failedtoCreateExportSesssion
			}
			
			exportSession.outputFileType = outputFormat.fileType
			exportSession.outputURL = destination
			
			try await exportSession.exportAsync()
			if self.deleteSource { try? FileManager.default.removeItem(at: source) }

		}
		return destination
	}

	public func convert2() async throws -> URL {
		try await withCheckedThrowingContinuation { continuation in
			guard let format = outputFormat.formatID, let outputID = outputFormat.outputID else {
				continuation.resume(throwing: ConversionError.outputTypeNotSupported)
				return
			}
			
			try? FileManager.default.removeItem(at: destination)
			
			var totalBytesWritten: Int64 = 0
			var totalBytesRead: Int64 = 0
			var inputRef: ExtAudioFileRef!
			var outputRef: ExtAudioFileRef!
			var converter: AudioConverterRef!
			
			do {
				var size: UInt32 = 0
				var destinationDesc: AudioStreamBasicDescription!
				var sourceCount = 0
				
				for sourceURL in self.sources {
					self.progress?.wrappedValue = Double(sourceCount) / Double(self.sources.count)
					sourceCount += 1
					var sourceDesc = AudioStreamBasicDescription()
					try self.attempt("ExtAudioFileOpenURL") { ExtAudioFileOpenURL(sourceURL as CFURL, &inputRef) }
					size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
					try self.attempt("ExtAudioFileGetProperty input") { ExtAudioFileGetProperty(inputRef, kExtAudioFileProperty_FileDataFormat, &size, &sourceDesc) }
					
					if destinationDesc == nil {
						destinationDesc = try AudioStreamBasicDescription(source: sourceDesc, format: format)
						
						try self.attempt("ExtAudioFileCreateWithURL") { ExtAudioFileCreateWithURL(self.destination as CFURL, outputID, &destinationDesc, nil, AudioFileFlags.eraseFile.rawValue, &outputRef) }
					}
					
					var clientDesc = try AudioStreamBasicDescription(source: sourceDesc, format: kAudioFormatLinearPCM)
					let sampleSize = UInt32(MemoryLayout<Int32>.size)
					clientDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
					clientDesc.mBitsPerChannel = 8 * sampleSize
					clientDesc.mChannelsPerFrame = sourceDesc.mChannelsPerFrame
					clientDesc.mFramesPerPacket = 1
					clientDesc.mBytesPerFrame = sourceDesc.mChannelsPerFrame * sampleSize
					clientDesc.mBytesPerPacket = clientDesc.mBytesPerFrame
					clientDesc.mSampleRate = sourceDesc.mSampleRate
					clientDesc.mReserved = 0
					
					size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
					try self.attempt("ExtAudioFileSetProperty client input") { ExtAudioFileSetProperty(inputRef, kExtAudioFileProperty_ClientDataFormat, size, &clientDesc) }
					try self.attempt("ExtAudioFileSetProperty client output") { ExtAudioFileSetProperty(outputRef, kExtAudioFileProperty_ClientDataFormat, size, &clientDesc) }
					
					size = UInt32(MemoryLayout<AudioConverterRef>.size)
					try self.attempt("ExtAudioFileGetProperty AudioConverterRef") { ExtAudioFileGetProperty(outputRef, kExtAudioFileProperty_AudioConverter, &size, &converter) }
					
					// check for interuption handling here
					
					let bufferByteSize = 32768
					var currentSourceBytesRead: Int64 = 0
					let buffer = AudioBuffer(mNumberChannels: clientDesc.mChannelsPerFrame, mDataByteSize: UInt32(bufferByteSize), mData: UnsafeMutableRawPointer.allocate(byteCount: bufferByteSize, alignment: 8))
					let bytesPerFrame = clientDesc.mBytesPerFrame > 0 ? clientDesc.mBytesPerFrame : 1
					
					var sampleSkipCount = sourceURL == self.sources.first ? Int64((self.startOffset ?? 0) * sourceDesc.mSampleRate) : 0
					var maxSampleCount = (sourceURL == self.sources.last && self.endDuration != nil) ? Int64(self.endDuration! * sourceDesc.mSampleRate) : nil
					
					while true {
						let bufferList = AudioBufferList.allocate(maximumBuffers: 1)
						var numberOfFrames: UInt32 = 0
						bufferList[0] = buffer
						
						numberOfFrames = UInt32(bufferByteSize) / bytesPerFrame
						if let maxFrames = maxSampleCount, maxFrames < numberOfFrames {
							numberOfFrames = UInt32(maxFrames)
						} else if sampleSkipCount > 0, sampleSkipCount < numberOfFrames {
							numberOfFrames = UInt32(sampleSkipCount)
						}
						
						try self.attempt("ExtAudioFileRead load source") { ExtAudioFileRead(inputRef, &numberOfFrames, bufferList.unsafeMutablePointer) }
						totalBytesRead += Int64(numberOfFrames * bytesPerFrame)
						
						if numberOfFrames == 0 { break }			// all done!
						
						if let max = maxSampleCount {
							if max == 0 {
								break
							} else if max < numberOfFrames {
								try self.attempt("ExtAudioFileWrite write destination") { ExtAudioFileWrite(outputRef, UInt32(max), bufferList.unsafePointer) }
								totalBytesWritten += max
								break
							} else {
								maxSampleCount = max - Int64(numberOfFrames)
							}
						}
						
						currentSourceBytesRead += Int64(numberOfFrames)
						if sampleSkipCount >= numberOfFrames {
							sampleSkipCount -= Int64(numberOfFrames)
							continue
						}
						
						try self.attempt("ExtAudioFileWrite write destination") { ExtAudioFileWrite(outputRef, numberOfFrames, bufferList.unsafePointer) }
						totalBytesWritten += Int64(numberOfFrames)
					}
					if inputRef != nil { ExtAudioFileDispose(inputRef) }
					if self.deleteSource { try? FileManager.default.removeItem(at: sourceURL) }
				}
				
				if outputRef != nil { ExtAudioFileDispose(outputRef) }
				if converter != nil { AudioConverterDispose(converter) }
				
				continuation.resume(returning: self.destination)
			} catch {
				if outputRef != nil { ExtAudioFileDispose(outputRef) }
				if inputRef != nil { ExtAudioFileDispose(inputRef) }
				if converter != nil { AudioConverterDispose(converter) }
				
				continuation.resume(throwing: error)
			}
		}
		
		
	}
	
	enum AudioFileConverterError: Error, LocalizedError { case systemError(String, Int32)
		
	}
	
	func attempt(_ hint: String? = nil, closure: () -> OSStatus) throws {
		let result = closure()
		if result != 0 {
			throw AudioFileConverterError.systemError(hint ?? "AudioExt error", result)
		}
	}
}

extension AudioBuffer {
	func skip(count: Int64) {
		guard count > 0, count < mDataByteSize, mData != nil else { return }
		
		let bytes = mData!.bindMemory(to: UInt8.self, capacity: Int(mDataByteSize))
		
		for i in count..<Int64(mDataByteSize) {
			bytes[Int(i - count)] = bytes[Int(i)]
		}
	}
}

extension AudioStreamBasicDescription {
	init(source: AudioStreamBasicDescription, format: AudioFormatID) throws {
		self.init()
		
		mSampleRate = source.mSampleRate
		mFormatID = format
		
		if format == kAudioFormatLinearPCM {
			mChannelsPerFrame = source.mChannelsPerFrame
			mBitsPerChannel = 16
			mBytesPerPacket = 2 * mChannelsPerFrame
			mBytesPerFrame = mBytesPerPacket
			mFramesPerPacket = 1
			mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger // little-endian
		} else {
			mChannelsPerFrame = format == kAudioFormatiLBC ? 1 : source.mChannelsPerFrame
			
			var size = UInt32(MemoryLayout<Self>.size)
			let result = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &size, &self)
			if result != 0 { throw AudioFileConverter.AudioFileConverterError.systemError("Error initializing an AudioStreamBasicDescription \(result.stringValue)", result) }
		}
	}
}

extension OSStatus {
	var stringValue: String {
		let data = withUnsafeBytes(of: self.bigEndian, { Data($0) })
		
		// If all bytes are printable characters, we treat it like characters of a string
		if data.allSatisfy({ 0x20 <= $0 && $0 <= 0x7e }) {
			return String(data: data, encoding: .ascii)!
		} else {
			return String(self)
		}
	}
}

extension AudioFileConverter {
	func convertWAVTo16kHz(inputURL: URL, outputURL: URL) {
		 do {
			  // Initialize an AVAudioFile for the source file (48kHz).
			  let sourceFile = try AVAudioFile(forReading: inputURL)
			  
			  // Specify the target sample rate (16kHz).
			  let targetSampleRate = 16000.0
			  
			  // Create an audio format for the target sample rate.
			  let targetFormatSettings: [String: Any] = [
					AVFormatIDKey: kAudioFormatLinearPCM,
					AVSampleRateKey: targetSampleRate,
					AVLinearPCMBitDepthKey: 16,
					AVLinearPCMIsBigEndianKey: false,
					AVLinearPCMIsFloatKey: false
			  ]
			  
			  let targetFormat = AVAudioFormat(settings: targetFormatSettings)
			  
			  // Initialize an AVAudioConverter.
			  guard let converter = AVAudioConverter(from: sourceFile.processingFormat, to: targetFormat!) else {
					print("Error creating audio converter")
					return
			  }
			  
			  // Initialize an AVAudioFile for the output file (16kHz).
			  let outputFile = try AVAudioFile(forWriting: outputURL, settings: targetFormatSettings)
			  
			  // Set up buffer sizes for processing.
			  let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: AVAudioFrameCount(sourceFile.length))!
			  let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat!, frameCapacity: AVAudioFrameCount(targetSampleRate))!
			  
			  // Loop through and convert the audio.
			  while sourceFile.framePosition < sourceFile.length {
					try sourceFile.read(into: inputBuffer)
					
					// Convert the buffer.
					let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
						 outStatus.pointee = AVAudioConverterInputStatus.haveData
						 return inputBuffer
					}
					
					let status = converter.convert(to: outputBuffer, error: nil, withInputFrom: inputBlock)
					
					if status == .error || status == .endOfStream {
						 break
					}
					
					try outputFile.write(from: outputBuffer)
			  }
			  
			  // Close the output file.
			//  outputFile.close()
		 } catch {
			  print("Error: \(error)")
		 }
	}

}
