//
//  RecorderOutput.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Suite

public protocol SamplesHandler: AnyObject {
	func handle(buffer: CMSampleBuffer)
	func prepareToRecord() async throws
	func endRecording() async throws
}

public protocol RecorderOutput: SamplesHandler {	
	var containerURL: URL? { get }
}


