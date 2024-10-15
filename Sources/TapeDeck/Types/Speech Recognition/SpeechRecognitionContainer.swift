//
//  SpeechRecognitionContainer.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 9/12/24.
//

import SwiftUI

public struct SpeechRecognitionContainer<Content: View>: View {
	let content: (SpeechTranscription) -> Content
	@StateObject var transcript = SpeechTranscriptionist()
	@Binding var text: String
	@Binding var isRunning: Bool
	var pauseCallback: (() -> Void)?
	let includePendingText: Bool
	
	public init(text: Binding<String> = .constant(""), pauseCallback: (() -> Void)? = nil, running: Binding<Bool>, includePendingText: Bool = true, content: @escaping (SpeechTranscription) -> Content) {
		_text = text
		_isRunning = running
		self.content = content
		self.pauseCallback = pauseCallback
		self.includePendingText = includePendingText
	}
	
	func setup(isRunning: Bool) {
		Task {
			if !isRunning, transcript.isRunning {
				transcript.stop()
			} else if isRunning, !transcript.isRunning {
				do {
					try await transcript.start { kind in
						if case .pause = kind { pauseCallback?() }
					}
				} catch {
					print("failed to start transcription: \(error)")
					self.isRunning = false
				}
			}
		}
	}
	
	public var body: some View {
		VStack {
			content(transcript.currentTranscription)
		}
		.onChange(of: isRunning) { newValue in setup(isRunning: newValue) }
		.onAppear { setup(isRunning: isRunning) }
		.onChange(of: transcript.currentTranscription) { newTranscript in
			if !includePendingText {
				text = newTranscript.confidentText
			} else {
				let pending = newTranscript.recentText
				if !pending.isEmpty {
					text = newTranscript.confidentText + " " + pending
				} else {
					text = newTranscript.confidentText
				}
			}
		}
	}
}
