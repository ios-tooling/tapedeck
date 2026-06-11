//
//  AudioFileWriter.swift
//  TapeDeck
//
//	 Writes captured PCM buffers to a single audio file, converting sample rate
//	 and channel count when the requested format differs from the input.
//	 Confined to RecordingSession's actor context.
//
//  Created by Ben Gottlieb on 6/11/26.
//

@preconcurrency import AVFoundation

final class AudioFileWriter {
	let url: URL

	private let file: AVAudioFile
	private let targetFormat: AVAudioFormat
	private var converter: AVAudioConverter?
	private(set) var framesWritten: AVAudioFramePosition = 0

	var duration: TimeInterval { Double(framesWritten) / targetFormat.sampleRate }

	init(url: URL, format: AudioFormat, input: AVAudioFormat) throws {
		guard let target = AVAudioFormat(standardFormatWithSampleRate: format.targetSampleRate(for: input), channels: format.targetChannels(for: input)) else {
			throw TapeDeckError.unsupportedAudioFormat
		}

		self.url = url
		targetFormat = target

		try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		file = try AVAudioFile(forWriting: url, settings: format.fileSettings(for: input), commonFormat: .pcmFormatFloat32, interleaved: false)
		updateInputFormat(input)
	}

	func updateInputFormat(_ input: AVAudioFormat) {
		converter = input == targetFormat ? nil : AVAudioConverter(from: input, to: targetFormat)
	}

	func write(_ buffer: AVAudioPCMBuffer) throws {
		guard let converter else {
			try file.write(from: buffer)
			framesWritten += AVAudioFramePosition(buffer.frameLength)
			return
		}

		let ratio = targetFormat.sampleRate / buffer.format.sampleRate
		let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
		guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
			throw TapeDeckError.unsupportedAudioFormat
		}

		var consumed = false
		var conversionError: NSError?
		let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
			if consumed {
				inputStatus.pointee = .noDataNow
				return nil
			}
			consumed = true
			inputStatus.pointee = .haveData
			return buffer
		}

		if status == .error { throw conversionError ?? TapeDeckError.unsupportedAudioFormat }

		if converted.frameLength > 0 {
			try file.write(from: converted)
			framesWritten += AVAudioFramePosition(converted.frameLength)
		}
	}

	func finish() throws -> AudioFile {
		try file.close()
		return AudioFile(url: url)
	}
}
