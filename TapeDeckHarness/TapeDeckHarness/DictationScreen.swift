//
//  DictationScreen.swift
//  TapeDeckHarness
//
//	 Live dictation into a text field, plus the raw utterance list —
//	 exercises the Transcriber on both the iOS 18 and iOS 26 paths.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI
import TapeDeck

struct DictationScreen: View {
	@State private var text = ""

	private var transcriber: Transcriber { .instance }

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			TranscribedTextField("Tap the mic and speak…", text: $text)
				.textFieldStyle(.roundedBorder)

			Text("Utterances")
				.font(.headline)

			List(transcriber.conversation.utterances) { utterance in
				VStack(alignment: .leading) {
					Text(utterance.text)

					Text("confidence \(utterance.confidence, format: .number.precision(.fractionLength(2)))\(utterance.isFinal ? " · final" : " · tentative")")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.listStyle(.plain)
		}
		.padding()
	}
}
