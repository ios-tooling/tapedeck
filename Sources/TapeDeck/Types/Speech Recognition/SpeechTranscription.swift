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
	var phrases: [Phrase] = []
	
	mutating func finalize() {
		for index in phrases.indices {
			if phrases[index].confidence == 0.0 {
				phrases[index].confidence = 0.1
			}
		}
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
		phrases = []
	}
	
	mutating func replaceRecentText(with result: SFSpeechRecognitionResult?) {
		guard let recent = result?.bestTranscription else { return }

		let newPhrases = recent.segments.map { segment in
			Phrase(raw: segment.substring, options: segment.alternativeSubstrings, confidence: Double(segment.confidence))
		}

		phrases = phrases.filter { $0.confidence > 0.0 } + newPhrases
	}

	// iOS 26+ support: Update with plain text (SpeechAnalyzer results)
	// Note: SpeechAnalyzer results contain the FULL transcript so far, not incremental
	mutating func updateFromFullTranscript(_ text: String, previousText: String) {
		// Skip if text hasn't changed
		if text == previousText { return }

		// Find what's new by comparing with previous text
		let isUpdate = text.hasPrefix(previousText)

		if isUpdate && text.count > previousText.count {
			// Text was extended - finalize old text and add new as recent
			let newPortion = text.dropFirst(previousText.count)
			let newWords = newPortion.split(separator: " ").map(String.init)

			// Mark all existing recent text as confident
			for index in phrases.indices where phrases[index].confidence == 0.0 {
				phrases[index].confidence = 0.5
			}

			// Add new words as recent
			let newPhrases = newWords.map { word in
				Phrase(raw: word, options: [], confidence: 0.0)
			}
			phrases.append(contentsOf: newPhrases)
		} else if previousText.isEmpty {
			// Initial text - just add everything as recent
			let words = text.split(separator: " ").map(String.init)
			phrases = words.map { word in
				Phrase(raw: word, options: [], confidence: 0.0)
			}
		} else {
			// Text changed but doesn't extend previous (correction or replacement)
			// Be conservative: keep old confident text, replace only recent text
			let confidentPhrases = phrases.filter { $0.confidence > 0.0 }
			let words = text.split(separator: " ").map(String.init)
			let newPhrases = words.map { word in
				Phrase(raw: word, options: [], confidence: 0.0)
			}

			// Only replace if we have new text, otherwise keep everything
			if !newPhrases.isEmpty {
				phrases = confidentPhrases + newPhrases
			}
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
