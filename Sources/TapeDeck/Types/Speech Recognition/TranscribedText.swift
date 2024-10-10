//
//  TranscribedText.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/10/24.
//

import SwiftUI

public struct TranscribedText: View {
	let transcript: SpeechTranscription
	
	public init(transcript: SpeechTranscription) {
		self.transcript = transcript
	}
	
	public var body: some View {
		HStack {
			if #available(iOS 17.0, *) {
				Text(transcript.confidentText + " ").foregroundStyle(.primary) + Text(transcript.recentText).foregroundStyle(.tertiary)
			} else {
				Text(transcript.confidentText + " ").foregroundColor(.primary) + Text(transcript.recentText).foregroundColor(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	 }
}
