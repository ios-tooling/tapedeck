//
//  RecorderOutput.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Suite

public protocol RecorderOutput: AnyObject {
	func prepareToRecord() async throws
	func handle(buffer: CMSampleBuffer)
	func endRecording() async throws -> URL
}

