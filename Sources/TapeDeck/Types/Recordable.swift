//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Foundation

public enum RecordableState: String { case idle, recording, paused }

@MainActor public protocol Recordable: Observable {
	func record() async throws
	func pause()
	func resume() throws
	func stop()
	
	var state: RecordableState { get }
}

public extension RecordableState {
	var imageName: String {
		switch self {
		case .idle: "circle.fill"
		case .paused: "circle.fill"
		case .recording: "pause.fill"
		}
	}
}
