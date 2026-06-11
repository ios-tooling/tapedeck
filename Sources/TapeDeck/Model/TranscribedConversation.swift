//
//  TranscribedConversation.swift
//  TapeDeck
//
//	 A struct representing a transcribed conversation. It should contain an array of
//	 sentences/utterances/chunks of text, each its own structure. If diarization is available
//	 each element should indicate its speaker.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

public struct TranscribedConversation: Codable, Sendable, Equatable {
	public var utterances: [Utterance]

	public init(utterances: [Utterance] = []) {
		self.utterances = utterances
	}

	public var isEmpty: Bool { utterances.isEmpty }

	public var text: String {
		utterances.map { $0.text }.joined(separator: " ")
	}

	public var finalizedText: String {
		utterances.filter { $0.isFinal }.map { $0.text }.joined(separator: " ")
	}

	public var tentativeText: String {
		utterances.filter { !$0.isFinal }.map { $0.text }.joined(separator: " ")
	}

	mutating func append(_ utterance: Utterance) {
		utterances.append(utterance)
	}

	// live transcription repeatedly revises its trailing tentative text; replace
	// rather than accumulate it
	mutating func replaceTentative(with utterance: Utterance?) {
		utterances.removeAll { !$0.isFinal }
		if let utterance { utterances.append(utterance) }
	}
}
