//
//  RecorderOutput.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation
import AVFoundation
import Suite

public protocol SamplesHandler: Actor {
	func handle(buffer: CMSampleBuffer) async
	func prepareToRecord() async throws
	func endRecording() async throws -> URL?
}

public protocol RecorderOutput: SamplesHandler {	
	var containerURL: URL? { get }
}
#endif
