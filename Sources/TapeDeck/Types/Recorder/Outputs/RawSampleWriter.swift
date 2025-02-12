//
//  RawSampleWriter.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 2/11/25.
//

import Foundation
import AVFoundation


@MainActor class RawSampleWriter {
	let url: URL
	var data = Data()
	var hasWritten = true
	
	init(url: URL) {
		self.url = url
	}
	
	func append(_ buffer: CMSampleBuffer) {
		guard let new = buffer.sampleData else { return }
		
		hasWritten = false
		data.append(contentsOf: new)
	}
	
	func close() {
		if hasWritten { return }
		
		if data.isEmpty {
			print("Nothing to save")
			return
		}
		hasWritten = true
		print("Saving \(data.count) bytes")
		do {
			try data.write(to: url)
		} catch {
			print("Failed to write raw audio data: \(error)")
		}
	}
}
