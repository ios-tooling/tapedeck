//
//  TranscribedTextField.swift
//  TapeDeck
//
//	 a TextField that is both editable and streams in transcribed text from the
//	 Transcriber. Finalized utterances are appended to the bound text; tentative
//	 text is shown dimmed below until it firms up.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

public struct TranscribedTextField: View {
	@Binding var text: String
	let prompt: String

	private var transcriber: Transcriber { .instance }

	public init(_ prompt: String = "", text: Binding<String>) {
		self.prompt = prompt
		_text = text
	}

	public var body: some View {
		HStack(alignment: .firstTextBaseline) {
			VStack(alignment: .leading, spacing: 2) {
				TextField(prompt, text: $text, axis: .vertical)

				if transcriber.isTranscribing, !transcriber.tentativeText.isEmpty {
					Text(transcriber.tentativeText)
						.foregroundStyle(.secondary)
						.italic()
				}
			}

			Button(action: toggleDictation) {
				Image(systemName: transcriber.isTranscribing ? "mic.fill" : "mic")
					.symbolRenderingMode(.multicolor)
					.contentTransition(.symbolEffect(.replace))
			}
			.buttonStyle(.plain)
		}
		.task {
			for await utterance in transcriber.utterances() {
				appendFinalized(utterance.text)
			}
		}
		.onDisappear {
			if transcriber.isTranscribing { Task { await transcriber.stop() } }
		}
	}

	private func appendFinalized(_ newText: String) {
		guard !newText.isEmpty else { return }

		if text.isEmpty {
			text = newText
		} else {
			text += text.hasSuffix(" ") ? newText : " " + newText
		}
	}

	private func toggleDictation() {
		Task {
			if transcriber.isTranscribing {
				await transcriber.stop()
			} else {
				transcriber.clear()
				try? await transcriber.start()
			}
		}
	}
}
