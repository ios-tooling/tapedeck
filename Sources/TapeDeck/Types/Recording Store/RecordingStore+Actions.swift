//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/2/23.
//

import Foundation
import AVFoundation
import Suite

public extension RecordingStore {
	func startRecording(at target: URL? = nil, segmented: Bool = true) async throws {
		var url = target ?? newRecordingURL()
		//let new = Recording.new(at: url)
		
		let output: RecorderOutput
		
		if segmented {
			url = url.appendingPathExtension(RecordingPackage.fileExtension)
			output = OutputSegmentedRecording(in: url, bufferDuration: 1)
		} else{
			url = url.appendingPathExtension("m4a")
			output = OutputSingleFileRecording(url: url, type: .m4a)
		}
		
		try await Recorder.instance.startRecording(to: output)
	}
	
	func endRecording() async throws {
		try await Recorder.instance.stop()
	}
	
	func newRecordingURL() -> URL {
		let dateString = DateFormatter.iso8601.string(from: Date()).replacingOccurrences(of: ":", with: "-")
		let filename = "Recorded at \(dateString)"
		
		return mainRecordingDirectory.appendingPathComponent(filename)
	}
}
