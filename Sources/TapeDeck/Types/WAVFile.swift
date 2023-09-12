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
	public var sampleChunks: [Chunk] { chunks.filter { $0.header.chunkMarker == "data".fourCharacterCode }}
	
	enum WAVError: Error { case missingFormatHeader }
	
	public var isPCM: Bool { mainHeader.type == 65534 }
	public var sampleRate: Int { Int(mainHeader?.samplesPerSecond ?? 0) }
	public var numberOfChannels: Int { Int(mainHeader?.channels ?? 0) }
	
	public struct Chunk {
		public let header: ChunkHeader
		public let format: FormatChunk?
		public var size: Int { Int(header.size) }
		public let data: Data?
		public var numberOfSamples: Int? { data == nil ? nil : (data!.count / 2) }
		public var name: String { header.chunkMarker.fourCharacterCode }
		public var samples: [Int16]? {
			data?.withUnsafeBytes { raw in
				let samples: [Int16] = raw.bindMemory(to: Int16.self) + []
				return samples
			}

		}
	}
	
	public init(sampleRate: Int, channels: Int = 1, bitsPerSample: Int = 16) {
		header = FileHeader(type: "RIFF".fourCharacterCode, size: 20, wavType: "WAVE".fourCharacterCode)
		url = .temp
		mainHeader = FormatChunk(
			chunkMarker: "fmt ".fourCharacterCode,
			size: UInt32(20),
			type: UInt16(1),
			channels: UInt16(channels),
			samplesPerSecond: UInt32(sampleRate),
			bytesPerSecond: UInt32(sampleRate * channels * bitsPerSample) / 8,
			blockSize: 2,
			bitsPerSample: UInt16(bitsPerSample)
		)
	}
	
	public func add(samples: [Int16], andFormat: Bool = true) {
		samples.withUnsafeBufferPointer { raw in
			raw.withMemoryRebound(to: UInt8.self) { buffer in
				if andFormat {
					chunks.append(.init(header: .init(chunkMarker: "data".fourCharacterCode, size: UInt32(samples.count * 2)), format: mainHeader, data: Data(buffer)))
				} else {
					chunks.append(.init(header: .init(chunkMarker: "data".fourCharacterCode, size: UInt32(samples.count * 2)), format: nil, data: Data(buffer)))
				}
			}
		}
	}
	
	public func write(to url: URL) throws {
		var data = Data()
		
		for chunk in chunks {
			if var format = chunk.format {
				format.size = UInt32(MemoryLayout<FormatChunk>.size) - 8
				data += Data(bytes: &format, count: MemoryLayout<FormatChunk>.size)

			}
			var head = chunk.header
			data += Data(bytes: &head, count: MemoryLayout<ChunkHeader>.size)
			if let samples = chunk.data { data += samples }
		}
		
		header.size = UInt32(data.count + 4)
		data = Data(bytes: &header!, count: MemoryLayout<FileHeader>.size) + data
		try data.write(to: url)
	}
	
	public init(url: URL) throws {
		self.url = url
		try load()
	}
	
	subscript(type: String) -> Chunk? {
		chunks.first { $0.header.chunkMarker == type.fourCharacterCode }
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
		var size: UInt32
		let wavType: UInt32			// 'WAVE'
	}
	
	public struct FormatChunk {				// 'fmt '
		public let chunkMarker: UInt32
		public var size: UInt32
		public let type: UInt16
		public let channels: UInt16
		public let samplesPerSecond: UInt32
		public let bytesPerSecond: UInt32
		public let blockSize: UInt16
		public let bitsPerSample: UInt16
		public var cbSize: UInt16 = 22
		public var validBitsPerSample: UInt16 = 16
		public var speakerPositionMask: UInt32 = 4
		public var guid1: UInt32 = 1
		public var guid2: UInt32 = 1048576
		public var guid3: UInt32 = 2852126848
		public var guid4: UInt32 = 1905997824
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
