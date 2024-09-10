//
//  Transcription.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation
import Speech

public struct SpeechTranscription: Codable {
	var phrases: [Phrase] = []
	
	var confidentWords: [String] {
		phrases.filter { $0.confidence > 0.0 }.map { $0.raw }
	}
	
	var confidentText: String { confidentWords.joined(separator: " ") }
	
	var recentWords: [String] {
		phrases.filter { $0.confidence == 0.0 }.map { $0.raw }
	}

	var recentText: String { recentWords.joined(separator: " ") }

	mutating func replaceRecentText(with result: SFSpeechRecognitionResult?) {
		guard let recent = result?.bestTranscription else { return }
		
		let newPhrases = recent.segments.map { segment in
			Phrase(raw: segment.substring, options: segment.alternativeSubstrings, confidence: Double(segment.confidence))
		}

		phrases = phrases.filter { $0.confidence > 0.0 } + newPhrases
	}
}

extension SpeechTranscription {
	public struct Phrase: Codable, Equatable {
		public let raw: String
		public let options: [String]
		public let confidence: Double
	}
}
