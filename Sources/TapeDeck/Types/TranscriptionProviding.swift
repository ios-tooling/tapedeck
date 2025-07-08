//
//  TranscriptionProviding.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/7/25.
//

import SwiftUI

@MainActor public protocol TranscriptionProviding: Observable {
	var finalizedTranscript: AttributedString { get }
	var pendingTranscript: AttributedString { get }
}
