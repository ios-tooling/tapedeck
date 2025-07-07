//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Foundation

public enum RecordableState: String { case idle, recording, paused }

public protocol Recordable: Observable {
	@MainActor func record() async throws
	@MainActor func pause()
	@MainActor func resume() throws
	@MainActor func stop() async
	
	@MainActor var state: RecordableState { get }
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
