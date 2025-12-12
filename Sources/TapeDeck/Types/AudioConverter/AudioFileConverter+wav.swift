//
//  AudioFileConverter+wav.swift
//
//
//  Created by Ben Gottlieb on 9/7/23.
//

#if os(iOS)
import Foundation
import AVFoundation

extension AudioFileConverter {
	public static func convert(m4a url: URL, toWAV outputURL: URL?, deleteSource: Bool = false) async throws {
		var error: OSStatus = noErr
		var destinationFile: ExtAudioFileRef?
		var sourceFile: ExtAudioFileRef?
		let outputURL = outputURL ?? url.deletingPathExtension().appendingPathExtension("wav")

		var srcFormat = AudioStreamBasicDescription()
		var dstFormat = AudioStreamBasicDescription()
		
		ExtAudioFileOpenURL(url as CFURL, &sourceFile)
		guard let sourceFile else { throw ConversionError.failedtoCreateSourceFile }

		var thePropertySize: UInt32 = UInt32(MemoryLayout.stride(ofValue: srcFormat))
		
		ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &srcFormat)
		
		dstFormat.mSampleRate = 16000.0
		dstFormat.mFormatID = kAudioFormatLinearPCM
		dstFormat.mChannelsPerFrame = 1
		dstFormat.mBitsPerChannel = 16
		dstFormat.mBytesPerPacket = 2 * dstFormat.mChannelsPerFrame
		dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame
		dstFormat.mFramesPerPacket = 1
		dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger
		
		// Create destination file
		error = ExtAudioFileCreateWithURL(outputURL as CFURL, kAudioFileWAVEType, &dstFormat, nil, AudioFileFlags.eraseFile.rawValue, &destinationFile)
		if error != 0 { throw ConversionError.OSError(error) }
		guard let destinationFile else { throw ConversionError.failedtoCreateExportFile }
		
		error = ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, thePropertySize, &dstFormat)
		if error != 0 { throw ConversionError.OSError(error) }
		
		error = ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, thePropertySize, &dstFormat)
		if error != 0 { throw ConversionError.OSError(error) }
		
		let bufferLength: UInt32 = 32768
		var sourceFrameOffset: UInt32 = 0
		let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(bufferLength), alignment: 8)
		
		while true {
			let audioBuffer = AudioBuffer(mNumberChannels: 2, mDataByteSize: bufferLength, mData: buffer)
			var fillBufList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
			var numFrames: UInt32 = 0
			
			if dstFormat.mBytesPerFrame > 0 { numFrames = bufferLength / dstFormat.mBytesPerFrame }
			
			error = ExtAudioFileRead(sourceFile, &numFrames, &fillBufList)
			if error != 0 { throw ConversionError.OSError(error) }
			
			if numFrames == 0 {
				error = noErr;
				break;
			}
			
			sourceFrameOffset += numFrames
			error = ExtAudioFileWrite(destinationFile, numFrames, &fillBufList)
			if error != 0 { throw ConversionError.OSError(error) }
		}
		
		error = ExtAudioFileDispose(destinationFile)
		if error != 0 { throw ConversionError.OSError(error) }
		error = ExtAudioFileDispose(sourceFile)
		if error != 0 { throw ConversionError.OSError(error) }
		if deleteSource { try? FileManager.default.removeItem(at: url) }
	}
}
#endif
