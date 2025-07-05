//
//  TranscriptionManager.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/1/25.
//

import SwiftUI

@Observable @MainActor public class TranscriptionManager {
	public static let instance = TranscriptionManager()
	
	var recorders: [AudioRecorder] = []
	
	public init() { }
	
	public var activeRecorder: Recordable {
		recorders.first ?? newRecorder()
	}
	
	func newRecorder() -> Recordable {
		let recorder = AudioRecorder()
		recorders.append(recorder)
		return recorder
	}
}

extension TranscriptionManager: Recordable {
	public func record() async throws { try await activeRecorder.record() }
	public func pause() { activeRecorder.pause() }
	
	public func resume() throws { try activeRecorder.resume() }
	public func stop() { activeRecorder.stop() }
	public var state: RecordableState { activeRecorder.state }
	
	
}
