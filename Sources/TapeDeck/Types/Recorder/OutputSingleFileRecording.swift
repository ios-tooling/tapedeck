//
//  OutputSingleFileRecording.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Suite

public class OutputSingleFileRecording: RecorderOutput {
	let url: URL
	
	var assetWriter: AVAssetWriter!
	var assetWriterInput: AVAssetWriterInput!
	var sampleRate: Int64 = 44100
	var samplesRead: Int64 = 0
	var recordingDuration: TimeInterval { TimeInterval(samplesRead / sampleRate) }
	var outputType = Recorder.AudioFileType.wav
	var internalType = Recorder.AudioFileType.wav
	
	public var containerURL: URL? { url }
	public init(url dest: URL, type: Recorder.AudioFileType = .wav) {
		url = dest.deletingPathExtension().appendingPathExtension(internalType.fileExtension)
		outputType = type

		let parent = url.deletingLastPathComponent()
		try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
	}

	public func handle(buffer sampleBuffer: CMSampleBuffer) {
		guard let assetWriterInput else { return }
		if !assetWriterInput.append(sampleBuffer) {
			logg("Failed to append buffer, \(self.assetWriter.error?.localizedDescription ?? "unknown error")")
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
	
	public func endRecording() async throws -> URL {
		await closeCurrentWriter()
		
		if internalType != outputType {
			let converter = AudioFileConverter(source: url, to: outputType, at: outputType.url(from: url), deletingSource: true, progress: nil)
			return try await converter.convert()
		}
		
		return url
	}
	
	func closeCurrentWriter() async {
		guard let input = assetWriterInput, let writer = assetWriter else { return }
		
		input.markAsFinished()
		await writer.finishWriting()
		
		assetWriterInput = nil
		assetWriter = nil
	}
}
