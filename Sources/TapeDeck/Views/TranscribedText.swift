//
//  TranscribedText.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/7/25.
//

import SwiftUI

public struct TranscribedText: View {
	var transcriber: any TranscriptionProviding
	
	public init(transcriber: any TranscriptionProviding) {
		self.transcriber = transcriber
	}
	
	public var body: some View {
		Text(transcriber.finalizedTranscript + transcriber.pendingTranscript)
	}
}
