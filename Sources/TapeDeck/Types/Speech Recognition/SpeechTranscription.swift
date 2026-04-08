//
//  Transcription.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

#if os(iOS)
import Foundation
import Speech

public struct SpeechTranscription: Codable, Equatable, Hashable {
	var finalizedPhrases: [Phrase] = []
	var tentativePhrases: [Phrase] = []

	public var phrases: [Phrase] {
		finalizedPhrases + tentativePhrases
	}
	
	mutating func finalize() {
		// Move any tentative phrases to finalized with minimum confidence
		for phrase in tentativePhrases {
			var finalizedPhrase = phrase
			if finalizedPhrase.confidence == 0.0 {
				finalizedPhrase.confidence = 0.1
			}
			finalizedPhrases.append(finalizedPhrase)
		}
		tentativePhrases = []
	}
	
	public var confidentWords: [String] {
		phrases.filter { $0.confidence > 0.0 }.map { $0.raw }
	}
	
	public var confidentText: String { confidentWords.joined(separator: " ") }

	public var allWords: [String] { phrases.map { $0.raw } }
	
	public var allText: String { allWords.joined(separator: " ") }

	public var recentWords: [String] {
		phrases.filter { $0.confidence == 0.0 }.map { $0.raw }
	}

	public var recentText: String { recentWords.joined(separator: " ") }

	public mutating func reset() {
		finalizedPhrases = []
		tentativePhrases = []
	}
	
	mutating func replaceRecentText(with result: SFSpeechRecognitionResult?) {
		guard let recent = result?.bestTranscription else { return }

		let newPhrases = recent.segments.map { segment in
			Phrase(raw: segment.substring, options: segment.alternativeSubstrings, confidence: Double(segment.confidence))
		}

		// Split into finalized and tentative based on confidence
		finalizedPhrases = newPhrases.filter { $0.confidence > 0.0 }
		tentativePhrases = newPhrases.filter { $0.confidence == 0.0 }
	}

	// iOS 26+ support: Update with plain text (SpeechAnalyzer results)
	// Note: SpeechAnalyzer results contain the FULL transcript so far, not incremental
	mutating func updateFromFullTranscript(_ text: String, isFinal: Bool) {
		let words = text.split(separator: " ").map(String.init)
		let newPhrases = words.map { word in
			Phrase(raw: word, options: [], confidence: isFinal ? 0.5 : 0.0)
		}

		if isFinal {
			// Final result - add to finalized and clear tentative
			finalizedPhrases.append(contentsOf: newPhrases)
			tentativePhrases = []
		} else {
			// Non-final result - replace tentative (keep finalized)
			tentativePhrases = newPhrases
		}
	}
}

extension SpeechTranscription {
	public struct Phrase: Codable, Equatable, Hashable {
		public let raw: String
		public let options: [String]
		public var confidence: Double
	}
}
#endif
