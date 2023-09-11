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
	public var chunkHeaders: [ChunkHeader] = []
	public var mainHeader: FormatChunk!
	public var chunks: [Chunk] = []

	enum WAVError: Error { case missingFormatHeader }
	
	public var isPCM: Bool { mainHeader.type == 65534 }
	public var sampleRate: Int { Int(mainHeader?.rate ?? 0) }
	public var numberOfChannels: Int { Int(mainHeader?.channels ?? 0) }
	
	public struct Chunk {
		public let header: FormatChunk
		public let data: Data
		public var numberOfSamples: Int { data.count / 2 }
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
			chunkHeaders.append(chunkHeader)
			let kind = chunkHeader.chunkMarker.fourCharacterCode

			switch kind {
			case "fmt ":
				mainHeader = try data.peek(type: FormatChunk.self)
				currentHeader = mainHeader
				_ = try data.consume(bytes: 8 + Int(chunkHeader.size))

			case "data":
				guard let currentHeader else { throw WAVError.missingFormatHeader}
				_ = try data.consume(bytes: 8)
				let bytes = try data.consume(bytes: Int(chunkHeader.size))
				chunks.append(.init(header: currentHeader, data: bytes))

			case "FLLR", "JUNK":
				_ = try data.consume(bytes: 8 + Int(chunkHeader.size))
				
				
			default:
				print("Unknown chunk kind: \(kind)")
				_ = try data.consume(bytes: 8 + Int(chunkHeader.size))
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
		public var name: String { chunkMarker.fourCharacterCode }
	}
}
