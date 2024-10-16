//
//  OutputSingleFileRecording.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Suite

public actor OutputSingleFileRecording: RecorderOutput, CustomStringConvertible {
	nonisolated let url: URL
	
	public var assetWriter: AVAssetWriter!
	var assetWriterInput: AVAssetWriterInput!
	var sampleRate: Int64 = 44100
	var samplesRead: Int64 = 0
	var recordingDuration: TimeInterval { TimeInterval(samplesRead / sampleRate) }
	public var outputType = Recorder.AudioFileType.wav16k
	var internalType = Recorder.AudioFileType.wav48k
	
	public var containerURL: URL? { url }
	public init(url dest: URL, type: Recorder.AudioFileType = .wav16k) {
		url = dest.deletingPathExtension().appendingPathExtension(internalType.fileExtension)
		outputType = type

		let parent = url.deletingLastPathComponent()
		try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
	}

	public func handle(buffer sampleBuffer: CMSampleBuffer) {
		guard let assetWriterInput else { return }
		if !assetWriterInput.append(sampleBuffer) {
			print("Failed to append buffer, \(self.assetWriter.error?.localizedDescription ?? "unknown error")")
		}
		samplesRead += Int64(sampleBuffer.numSamples)
	}

	public func prepareToRecord() throws {
		samplesRead = 0

		assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: internalType.settings)
		assetWriterInput.expectsMediaDataInRealTime = true
		
		try? FileManager.default.removeItem(at: url)
		assetWriter = try AVAssetWriter(outputURL: url, fileType: internalType.fileType)
		assetWriterInput.expectsMediaDataInRealTime = true
		assetWriter.add(assetWriterInput)
		assetWriter.startWriting()
		assetWriter.startSession(atSourceTime: CMTime.zero)
	}
	
	public func endRecording() async throws {
		await closeCurrentWriter()
		
		if internalType != outputType {
			let converter = await AudioFileConverter(source: url, to: outputType, at: outputType.url(from: url), progress: nil)
			try await converter.convert()
		}
	}
	
	nonisolated public var description: String {
		"Audio file at \(url.path)"
	}
	
	func closeCurrentWriter() async {
		guard let input = assetWriterInput, let writer = assetWriter else { return }
		
		input.markAsFinished()
		await writer.finishWriting()
		
		assetWriterInput = nil
		assetWriter = nil
	}
}
