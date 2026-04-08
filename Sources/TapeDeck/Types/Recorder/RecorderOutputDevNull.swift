//
//  OutputDevNull.swift
//
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation
import AVFoundation
import Suite

public actor OutputDevNull: RecorderOutput {
	public static let instance = OutputDevNull()
	
	public func prepareToRecord() async throws {
		
	}
	
	public var containerURL: URL? { nil }

	public func handle(buffer: CMSampleBuffer) {
		
	}

	public func endRecording() async throws -> URL? {
		nil
	}
}
#endif
