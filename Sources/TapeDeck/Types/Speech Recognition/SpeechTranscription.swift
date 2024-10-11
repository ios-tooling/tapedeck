//
//  Transcription.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

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
}

extension SpeechTranscription {
	public struct Phrase: Codable, Equatable, Hashable {
		public let raw: String
		public let options: [String]
		public var confidence: Double
	}
}
