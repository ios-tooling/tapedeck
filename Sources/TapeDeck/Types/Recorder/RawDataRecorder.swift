//
//  RawDataRecorder.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 2/22/25.
//

#if os(iOS)
import Foundation
import AVFoundation

public actor RawDataRecorder: RecorderOutput {
	nonisolated let directory: URL
	var wavMirror: OutputSegmentedRecording?
	var chunkCount = 0
	var samplesPerFile = 44_100 * 5
	var collectedSamples = Data()
	var numberOfCollectedSamples = 0
	
	public init(url: URL) {
		directory = url
		try? FileManager.default.createDirectory(at: rawURL, withIntermediateDirectories: true)
		
		
		try? FileManager.default.createDirectory(at: wavURL, withIntermediateDirectories: true)
		Task { await setupWavMirror() }
	}

	func setupWavMirror() {
		wavMirror = OutputSegmentedRecording(in: wavURL, outputType: .wav16k)
	}
	
	nonisolated public var containerURL: URL? { directory }
	nonisolated public var rawURL: URL { directory.appendingPathComponent("raw", conformingTo: .directory) }
	nonisolated public var wavURL: URL { directory.appendingPathComponent("wav", conformingTo: .directory) }

	
	public func handle(buffer: CMSampleBuffer) async {
		chunkCount += 1
		if let data = buffer.sampleData {
			collectedSamples.append(data)
			numberOfCollectedSamples += buffer.numSamples
			
			if numberOfCollectedSamples > samplesPerFile {
				let filename = String.fileName(forChunk: chunkCount, offset: 0, duration: 0, ext: "data")
				let url = rawURL.appendingPathComponent(filename)
				do {
					try collectedSamples.write(to: url)
				} catch {
					print("Failed to write out \(numberOfCollectedSamples) samples: \(error)")
				}
				collectedSamples = Data()
				numberOfCollectedSamples = 0
			}
		}
		
		await wavMirror?.handle(buffer: buffer)
	}

	public func prepareToRecord() async throws {
		try await wavMirror?.prepareToRecord()
	}

	public func endRecording() async throws -> URL? {
		try await wavMirror?.endRecording()
		return containerURL
	}
}


#endif
