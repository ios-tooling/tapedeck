//
//  AudioFormat.swift
//  TapeDeck
//
//	 The on-disk format for recorded audio. A nil sampleRate or channels means
//	 "match the input".
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

public struct AudioFormat: Sendable, Codable, Equatable {
	public enum Container: String, Sendable, Codable {
		case m4a, wav

		var fileExtension: String { rawValue }
	}

	public var container: Container
	public var sampleRate: Double?
	public var channels: UInt32?
	public var bitRate: Int?

	public init(container: Container, sampleRate: Double? = nil, channels: UInt32? = nil, bitRate: Int? = nil) {
		self.container = container
		self.sampleRate = sampleRate
		self.channels = channels
		self.bitRate = bitRate
	}

	public static let m4a = AudioFormat(container: .m4a, bitRate: 96_000)
	public static let wav = AudioFormat(container: .wav)
	public static let wav16k = AudioFormat(container: .wav, sampleRate: 16_000, channels: 1)

	public var fileExtension: String { container.fileExtension }

	func targetSampleRate(for input: AVAudioFormat) -> Double { sampleRate ?? input.sampleRate }
	func targetChannels(for input: AVAudioFormat) -> UInt32 { channels ?? input.channelCount }

	func fileSettings(for input: AVAudioFormat) -> [String: Any] {
		let rate = targetSampleRate(for: input)
		let channelCount = targetChannels(for: input)

		switch container {
		case .m4a:
			return [
				AVFormatIDKey: kAudioFormatMPEG4AAC,
				AVSampleRateKey: rate,
				AVNumberOfChannelsKey: channelCount,
				AVEncoderBitRateKey: bitRate ?? 96_000,
			]

		case .wav:
			return [
				AVFormatIDKey: kAudioFormatLinearPCM,
				AVSampleRateKey: rate,
				AVNumberOfChannelsKey: channelCount,
				AVLinearPCMBitDepthKey: 16,
				AVLinearPCMIsFloatKey: false,
				AVLinearPCMIsBigEndianKey: false,
				AVLinearPCMIsNonInterleaved: false,
			]
		}
	}
}
