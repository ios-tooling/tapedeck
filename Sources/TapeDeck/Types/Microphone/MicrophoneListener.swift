//
//  MicrophoneListener.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation

protocol MicrophoneListener: AnyObject {
	func start() async throws
	func stop() async throws
}
#endif
