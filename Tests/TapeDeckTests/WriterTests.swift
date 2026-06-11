//
//  WriterTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Testing
import AVFoundation
@testable import TapeDeck

struct WriterTests {
	let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

	func tempURL(ext: String) -> URL {
		FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
	}

	// one second of a 440Hz sine at half amplitude
	func oneSecondBuffer() -> AVAudioPCMBuffer {
		let frames = AVAudioFrameCount(inputFormat.sampleRate)
		let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frames)!
		buffer.frameLength = frames
		let samples = buffer.floatChannelData![0]
		for index in 0..<Int(frames) {
			samples[index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(inputFormat.sampleRate))
		}
		return buffer
	}

	@Test func singleFileWriterProducesPlayableM4A() async throws {
		let url = tempURL(ext: "m4a")
		defer { try? FileManager.default.removeItem(at: url) }

		let writer = try AudioFileWriter(url: url, format: .m4a, input: inputFormat)
		for _ in 0..<2 { try writer.write(oneSecondBuffer()) }
		let file = try writer.finish()

		#expect(abs(writer.duration - 2) < 0.01)
		let duration = try await file.duration()
		#expect(abs(duration - 2) < 0.1)
	}

	@Test func wavWriterResamplesTo16k() async throws {
		let url = tempURL(ext: "wav")
		defer { try? FileManager.default.removeItem(at: url) }

		let writer = try AudioFileWriter(url: url, format: .wav16k, input: inputFormat)
		for _ in 0..<2 { try writer.write(oneSecondBuffer()) }
		let file = try writer.finish()

		let reread = try AVAudioFile(forReading: url)
		#expect(reread.fileFormat.sampleRate == 16_000)
		#expect(reread.fileFormat.channelCount == 1)
		let duration = try await file.duration()
		#expect(abs(duration - 2) < 0.05)											// resampler may swallow a few frames
	}

	@Test func segmentedWriterRotatesChunksAndTracksManifest() throws {
		let packageURL = tempURL(ext: RecordingPackage.fileExtension)
		defer { try? FileManager.default.removeItem(at: packageURL) }

		let writer = try SegmentedWriter(package: RecordingPackage(url: packageURL), format: .wav, chunkDuration: 2, ringDuration: nil, input: inputFormat)
		for _ in 0..<5 { try writer.write(oneSecondBuffer()) }
		let package = try writer.finish()

		let manifest = try package.loadManifest()
		#expect(manifest.chunks.count == 3)										// 2s + 2s + trailing 1s
		#expect(manifest.chunks.map { $0.duration } == [2, 2, 1])
		#expect(manifest.chunks.map { $0.start } == [0, 2, 4])
		#expect(package.duration == 5)
		#expect(package.chunkFiles.allSatisfy { $0.exists })
	}

	@Test func ringBufferPrunesOldChunks() throws {
		let packageURL = tempURL(ext: RecordingPackage.fileExtension)
		defer { try? FileManager.default.removeItem(at: packageURL) }

		let writer = try SegmentedWriter(package: RecordingPackage(url: packageURL), format: .wav, chunkDuration: 1, ringDuration: 2, input: inputFormat)
		var prunedChunkURL: URL?
		for second in 0..<5 {
			try writer.write(oneSecondBuffer())
			if second == 0 { prunedChunkURL = writer.package.url.appendingPathComponent("0. 0-1.wav") }
		}
		let package = try writer.finish()

		let manifest = try package.loadManifest()
		#expect(manifest.chunks.count <= 3)										// only the trailing ~2s window plus the open chunk
		#expect(manifest.chunks.first?.start ?? 0 >= 2)
		#expect(FileManager.default.fileExists(atPath: prunedChunkURL!.path) == false)
		#expect(manifest.chunks.last.map { $0.start + $0.duration } == 5)	// timeline is preserved
	}
}
