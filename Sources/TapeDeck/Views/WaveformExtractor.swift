//
//  WaveformExtractor.swift
//  TapeDeck
//
//	 Decodes audio to a normalized peak envelope (~100 peaks/second) on demand
//	 and caches it per file, so panning and zooming a waveform are served from
//	 memory after the first decode.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

actor WaveformExtractor {
	static let samplesPerSecond: Double = 100

	struct Source: Sendable, Equatable {
		let url: URL
		let timelineStart: TimeInterval

		static func sources(for recording: Recording) -> [Source] {
			switch recording {
			case .file(let file):
				return [Source(url: file.url, timelineStart: 0)]

			case .package(let package):
				guard let manifest = try? package.loadManifest() else { return [] }
				return manifest.chunks.map { Source(url: package.url.appendingPathComponent($0.filename), timelineStart: $0.start) }
			}
		}
	}

	private var cache: [URL: [Float]] = [:]

	func envelope(for url: URL) async throws -> [Float] {
		if let cached = cache[url] { return cached }
		let envelope = try await Self.decodeEnvelope(url: url, samplesPerSecond: Self.samplesPerSecond)
		cache[url] = envelope
		return envelope
	}

	// `bins` normalized peaks across the sources overlapping `range`, max peak
	// per bin; zeros where there's no audio
	func peaks(sources: [Source], range: ClosedRange<TimeInterval>, bins: Int) async throws -> [Float] {
		guard bins > 0, range.upperBound > range.lowerBound else { return [] }

		var result = [Float](repeating: 0, count: bins)
		let span = range.upperBound - range.lowerBound
		let samplesPerSecond = Self.samplesPerSecond

		for source in sources {
			let envelope = try await envelope(for: source.url)
			guard !envelope.isEmpty else { continue }

			let localStart = max(0, range.lowerBound - source.timelineStart)
			let localEnd = range.upperBound - source.timelineStart
			let startIndex = max(0, Int((localStart * samplesPerSecond).rounded(.down)))
			let endIndex = min(envelope.count, Int((localEnd * samplesPerSecond).rounded(.up)))
			guard endIndex > startIndex else { continue }

			for index in startIndex..<endIndex {
				let globalTime = source.timelineStart + Double(index) / samplesPerSecond
				let bin = Int(((globalTime - range.lowerBound) / span) * Double(bins))
				guard bin >= 0, bin < bins else { continue }
				result[bin] = max(result[bin], envelope[index])
			}
		}
		return result
	}

	private static func decodeEnvelope(url: URL, samplesPerSecond: Double) async throws -> [Float] {
		let asset = AVURLAsset(url: url)
		guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
		let formats = try await track.load(.formatDescriptions)
		guard let format = formats.first, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return [] }
		let nativeRate = asbd.pointee.mSampleRate

		let reader = try AVAssetReader(asset: asset)
		let settings: [String: Any] = [
			AVFormatIDKey: kAudioFormatLinearPCM,
			AVLinearPCMBitDepthKey: 16,
			AVLinearPCMIsBigEndianKey: false,
			AVLinearPCMIsFloatKey: false,
			AVNumberOfChannelsKey: 1,
		]
		let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
		output.alwaysCopiesSampleData = false
		reader.add(output)
		reader.startReading()

		let framesPerBin = max(1, Int((nativeRate / samplesPerSecond).rounded()))
		var envelope: [Float] = []
		var binPeak: Int16 = 0
		var framesInBin = 0

		while reader.status == .reading, let buffer = output.copyNextSampleBuffer() {
			guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
			let length = CMBlockBufferGetDataLength(block)
			var data = Data(count: length)
			data.withUnsafeMutableBytes { raw in
				_ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
			}
			data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
				for sample in raw.bindMemory(to: Int16.self) {
					let magnitude = sample == Int16.min ? Int16.max : abs(sample)
					if magnitude > binPeak { binPeak = magnitude }
					framesInBin += 1

					if framesInBin >= framesPerBin {
						envelope.append(Float(binPeak) / Float(Int16.max))
						binPeak = 0
						framesInBin = 0
					}
				}
			}
			CMSampleBufferInvalidate(buffer)
		}

		if framesInBin > 0 { envelope.append(Float(binPeak) / Float(Int16.max)) }
		return envelope
	}
}
