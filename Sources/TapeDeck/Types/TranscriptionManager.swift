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
