//
//  SpeechRecognitionContainer.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 9/12/24.
//

import SwiftUI

@available(iOS 17.0, *)
public struct SpeechRecognitionContainer<Content: View>: View {
	let content: (SpeechTranscription) -> Content
	@StateObject var transcript = SpeechTranscriptionist()
	@Binding var text: String
	let isRunning: Bool
	let includePendingText: Bool
	
	public init(text: Binding<String> = .constant(""), running: Bool, includePendingText: Bool = true, content: @escaping (SpeechTranscription) -> Content) {
		_text = text
		isRunning = running
		self.content = content
		self.includePendingText = includePendingText
	}
	
	public var body: some View {
		VStack {
			content(transcript.currentTranscription)
		}
		.onChange(of: isRunning, initial: true) {
			Task { try? await transcript.setRunning(isRunning) }
		}
		.onChange(of: transcript.currentTranscription) {
			if !includePendingText {
				text = transcript.currentTranscription.confidentText
			} else {
				let pending = transcript.currentTranscription.recentText
				if !pending.isEmpty {
					text = transcript.currentTranscription.confidentText + " " + pending
				} else {
					text = transcript.currentTranscription.confidentText
				}
			}
		}
	}
}
