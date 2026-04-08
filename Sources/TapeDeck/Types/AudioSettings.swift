//
//  AudioSettings.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation
import AVFoundation
import Combine

struct AudioSettings {
	let format: AudioFormatID
	var sampleRate: Int = 44100
	var numberOfChannels: Int = 2
	var bitRate: Int = 320000
	var quality: Int = .max
	let fileType: AudioFormatID
	
	func convert(seconds: TimeInterval) -> Int64 {
		Int64(TimeInterval(numberOfChannels * sampleRate) * seconds)
	}
	
	func convert(samples: Int64) -> TimeInterval {
		TimeInterval(samples) / TimeInterval(numberOfChannels * sampleRate)
	}
	
	static let m4a = AudioSettings(format: kAudioFormatMPEG4AAC, fileType: kAudioFileM4AType)
	static let mp3 = AudioSettings(format: kAudioFormatMPEGLayer3, fileType: kAudioFileMP3Type)
	static let wav = AudioSettings(format: kAudioFileWAVEType, sampleRate: 16000, numberOfChannels: 1, fileType: kAudioFileWAVEType)
	
	var settings: [String: Any] {
		[
			AVSampleRateKey: sampleRate,
			AVFormatIDKey: format,
			AVNumberOfChannelsKey: numberOfChannels,
			AVEncoderBitRateKey: bitRate,
			AVVideoQualityKey: quality,
			AVAudioFileTypeKey: fileType
		]
	}
}
#endif
