//
//  Recorder+AudioTypes.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation

extension Recorder {
	public struct AudioFileType: Equatable {
		var fileExtension: String
		var fileType: AVFileType
		
		static var defaultSampleRate = 44100
		
		var settings: [String: Any]
		var canConvertTo: Bool { formatID != nil }
	
		var formatID: AudioFormatID?
		var outputID: AudioFormatID?
		
		func url(from url: URL) -> URL {
			url.deletingPathExtension().appendingPathExtension(fileExtension)
		}
		
		public static func ==(lhs: AudioFileType, rhs: AudioFileType) -> Bool {
			lhs.fileType == rhs.fileType
		}

		public static var m4a: AudioFileType = {
			var channelLayout = AudioChannelLayout()
			channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
			
			let settings: [String: Any] = [
				AVFormatIDKey: kAudioFormatMPEG4AAC,
				AVSampleRateKey: AudioFileType.defaultSampleRate,
				AVEncoderBitRateKey: 128000,
				AVNumberOfChannelsKey: 2,
				AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout<AudioChannelLayout>.size)
			]

			return AudioFileType(fileExtension: "m4a", fileType: .m4a, settings: settings, formatID: kAudioFormatMPEG4AAC, outputID: kAudioFileM4AType)
		}()
		
		public static var wav: AudioFileType = {
			var channelLayout = AudioChannelLayout()
			channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
			
			let settings: [String: Any] = [
				AVFormatIDKey: Int(kAudioFormatLinearPCM),
				AVSampleRateKey: 16000.0,
				AVNumberOfChannelsKey: 1,
				AVLinearPCMIsBigEndianKey: false,
				AVLinearPCMIsFloatKey: false,
				AVLinearPCMBitDepthKey: 16,
				AVLinearPCMIsNonInterleaved: false,
//				AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue

//				AVFormatIDKey: kAudioFormatLinearPCM,
//				AVSampleRateKey: AudioFileType.defaultSampleRate,
//				AVLinearPCMBitDepthKey: 16,
//				AVLinearPCMIsFloatKey: false,
//				AVLinearPCMIsBigEndianKey: false,
//				AVLinearPCMIsNonInterleaved: false,
//			//	AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
//				AVNumberOfChannelsKey: 2,
//				AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout<AudioChannelLayout>.size)
			]

			return AudioFileType(fileExtension: "wav", fileType: .wav, settings: settings)
		}()

		public static var mp3: AudioFileType = {
			var channelLayout = AudioChannelLayout()
			channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
			
			let settings: [String: Any] = [
				AVFormatIDKey: kAudioFormatMPEGLayer3,
				AVSampleRateKey: AudioFileType.defaultSampleRate,
				AVLinearPCMBitDepthKey: 16,
				AVLinearPCMIsFloatKey: false,
				AVLinearPCMIsBigEndianKey: false,
				AVLinearPCMIsNonInterleaved: false,
				AVNumberOfChannelsKey: 2,
				AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout<AudioChannelLayout>.size)
			]

			return AudioFileType(fileExtension: "mp3", fileType: .mp3, settings: settings)
		}()
	}
}
