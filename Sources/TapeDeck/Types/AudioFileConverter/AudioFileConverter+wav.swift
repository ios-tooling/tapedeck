//
//  AudioFileConverter+wav.swift
//
//
//  Created by Ben Gottlieb on 9/7/23.
//

import Foundation
import AVFoundation

extension AudioFileConverter {
	public static func convert(m4a url: URL, toWAV outputWAV: URL?, deleteSource: Bool = false) async throws {
		var error : OSStatus = noErr
		var destinationFile : ExtAudioFileRef? = nil
		var sourceFile : ExtAudioFileRef? = nil
		let outputURL = outputWAV ?? url.deletingPathExtension().appendingPathExtension("wav")

		var srcFormat : AudioStreamBasicDescription = AudioStreamBasicDescription()
		var dstFormat : AudioStreamBasicDescription = AudioStreamBasicDescription()
		
		ExtAudioFileOpenURL(url as CFURL, &sourceFile)
		
		var thePropertySize: UInt32 = UInt32(MemoryLayout.stride(ofValue: srcFormat))
		
		ExtAudioFileGetProperty(sourceFile!,
										kExtAudioFileProperty_FileDataFormat,
										&thePropertySize, &srcFormat)
		
		dstFormat.mSampleRate = 16000.0  //Set sample rate
		dstFormat.mFormatID = kAudioFormatLinearPCM
		dstFormat.mChannelsPerFrame = 1
		dstFormat.mBitsPerChannel = 16
		dstFormat.mBytesPerPacket = 2 * dstFormat.mChannelsPerFrame
		dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame
		dstFormat.mFramesPerPacket = 1
		dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked |
		kAudioFormatFlagIsSignedInteger
		
		
		// Create destination file
		error = ExtAudioFileCreateWithURL(
			outputURL as CFURL,
			kAudioFileWAVEType,
			&dstFormat,
			nil,
			AudioFileFlags.eraseFile.rawValue,
			&destinationFile)
		
		if error != 0 { throw ConversionError.OSError(error) }
		
		error = ExtAudioFileSetProperty(sourceFile!,
												  kExtAudioFileProperty_ClientDataFormat,
												  thePropertySize,
												  &dstFormat)
		if error != 0 { throw ConversionError.OSError(error) }
		
		error = ExtAudioFileSetProperty(destinationFile!,
												  kExtAudioFileProperty_ClientDataFormat,
												  thePropertySize,
												  &dstFormat)
		if error != 0 { throw ConversionError.OSError(error) }
		
		let bufferByteSize : UInt32 = 32768
		var srcBuffer = [UInt8](repeating: 0, count: 32768)
		var sourceFrameOffset : ULONG = 0
		
		while(true){
			var fillBufList = AudioBufferList(
				mNumberBuffers: 1,
				mBuffers: AudioBuffer(
					mNumberChannels: 2,
					mDataByteSize: UInt32(srcBuffer.count),
					mData: &srcBuffer
				)
			)
			var numFrames : UInt32 = 0
			
			if(dstFormat.mBytesPerFrame > 0){
				numFrames = bufferByteSize / dstFormat.mBytesPerFrame
			}
			
			error = ExtAudioFileRead(sourceFile!, &numFrames, &fillBufList)
			if error != 0 { throw ConversionError.OSError(error) }
			
			if(numFrames == 0){
				error = noErr;
				break;
			}
			
			sourceFrameOffset += numFrames
			error = ExtAudioFileWrite(destinationFile!, numFrames, &fillBufList)
			if error != 0 { throw ConversionError.OSError(error) }
		}
		
		error = ExtAudioFileDispose(destinationFile!)
		if error != 0 { throw ConversionError.OSError(error) }
		error = ExtAudioFileDispose(sourceFile!)
		if error != 0 { throw ConversionError.OSError(error) }
		if deleteSource { try? FileManager.default.removeItem(at: url) }
	}
	
}
