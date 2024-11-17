//
//  TranscribedText.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/10/24.
//

import SwiftUI

public struct TranscribedText: View {
	let transcript: SpeechTranscription
	let preexistingText: String?
	
	public init(transcript: SpeechTranscription, preexistingText: String? = nil) {
		self.transcript = transcript
		self.preexistingText = preexistingText
	}
	
	public var body: some View {
		HStack {
			if #available(iOS 17.0, *) {
				Text((preexistingText ?? "") + transcript.confidentText + " ").foregroundStyle(.primary) + Text(transcript.recentText).foregroundStyle(.tertiary)
			} else {
				Text((preexistingText ?? "") + transcript.confidentText + " ").foregroundColor(.primary) + Text(transcript.recentText).foregroundColor(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	 }
}
