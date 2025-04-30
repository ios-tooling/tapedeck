//
//  MicrophoneListener.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation


protocol MicrophoneListener: AnyObject {
	func start() async throws
	func stop() async throws
}
