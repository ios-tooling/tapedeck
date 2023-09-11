//
//  WAVFile.swift
//
//
//  Created by Ben Gottlieb on 9/11/23.
//

import Foundation
import Suite

public final class WAVFile {
	public let url: URL
	var header: FileHeader!
	public var mainHeader: FormatChunk!
	public var chunks: [Chunk] = []
	
	enum WAVError: Error { case missingFormatHeader }
	
	public var isPCM: Bool { mainHeader.type == 65534 }
	public var sampleRate: Int { Int(mainHeader?.rate ?? 0) }
	public var numberOfChannels: Int { Int(mainHeader?.channels ?? 0) }
	
	public struct Chunk {
		public let header: ChunkHeader
		public let format: FormatChunk?
		public var size: Int { Int(header.size) }
		public let data: Data?
		public var numberOfSamples: Int? { data == nil ? nil : (data!.count / 2) }
		public var name: String { header.chunkMarker.fourCharacterCode }
	}
	
	public init(sampleRate: Int, channels: Int = 1, bitsPerSample: Int = 16) {
		header = FileHeader(type: "RIFF".fourCharacterCode, size: 20, wavType: "WAVE".fourCharacterCode)
		url = .temp
		mainHeader = FormatChunk(
			chunkMarker: "fmt ".fourCharacterCode,
			size: UInt32(20),
			type: UInt16(65534),
			channels: UInt16(channels),
			rate: UInt32(sampleRate),
			rateBitsPerSampleBytes: UInt32((sampleRate * bitsPerSample * numberOfChannels) / 8),
			bytesPerSample: UInt16((bitsPerSample * channels) / 8),
			bitsPerSample: UInt16(bitsPerSample)
		)
	}
	
	func add(samples: [UInt16]) {
		samples.withUnsafeBufferPointer { raw in
			raw.withMemoryRebound(to: UInt8.self) { buffer in
				chunks.append(.init(header: .init(chunkMarker: "DATA".fourCharacterCode, size: UInt32(samples.count * 2)), format: nil, data: Data(buffer)))
			}
		}
	}
	
	func write(to url: URL) throws {
		var data = Data()
		data += Data(bytes: &header!, count: MemoryLayout<FileHeader>.size)
		
		for chunk in chunks {
			var head = chunk.header
			data += Data(bytes: &head, count: MemoryLayout<ChunkHeader>.size)
			if let samples = chunk.data { data += samples }
		}
		
		try data.write(to: url)
	}
	
	public init(url: URL) throws {
		self.url = url
		try load()
	}
	
	func load() throws {
		var data = try Data(contentsOf: url)
		
		header = try data.consume(type: FileHeader.self)
		var currentHeader: FormatChunk?
		
		while true {
			guard let chunkHeader = try? data.peek(type: ChunkHeader.self) else { break }
			let kind = chunkHeader.chunkMarker.fourCharacterCode
			
			switch kind {
			case "fmt ":
				mainHeader = try data.peek(type: FormatChunk.self)
				currentHeader = mainHeader
				_ = try data.consume(bytes: 8 + Int(chunkHeader.size))
				chunks.append(.init(header: chunkHeader, format: nil, data: nil))
				
			case "data":
				guard let currentHeader else { throw WAVError.missingFormatHeader}
				_ = try data.consume(bytes: 8)
				let bytes = try data.consume(bytes: Int(chunkHeader.size))
				chunks.append(.init(header: chunkHeader, format: currentHeader, data: bytes))
				
			case "FLLR", "JUNK":
				_ = try data.consume(bytes: 8 + Int(chunkHeader.size))
				chunks.append(.init(header: chunkHeader, format: nil, data: nil))
				
				
			default:
				print("Unknown chunk kind: \(kind)")
				_ = try data.consume(bytes: 8 + Int(chunkHeader.size))
				chunks.append(.init(header: chunkHeader, format: nil, data: nil))
			}
			
		}
	}
}

extension WAVFile {
	struct FileHeader {
		let type: UInt32
		let size: UInt32
		let wavType: UInt32			// 'WAVE'
	}
	
	public struct FormatChunk {				// 'fmt '
		public let chunkMarker: UInt32
		public let size: UInt32
		public let type: UInt16
		public let channels: UInt16
		public let rate: UInt32
		public let rateBitsPerSampleBytes: UInt32
		public let bytesPerSample: UInt16
		public let bitsPerSample: UInt16
	}
	
	public struct ChunkHeader {
		public let chunkMarker: UInt32		// 'data'
		public let size: UInt32
	}
}

extension String {
	var fourCharacterCode: UInt32 {
		precondition(count == 4)
		
		let ints = self.utf8.map { Int($0) }
		
		return UInt32(ints[0]) | UInt32(ints[1] << 8) | UInt32(ints[2] << 16) | UInt32(ints[3] << 24)
	}
	
}
