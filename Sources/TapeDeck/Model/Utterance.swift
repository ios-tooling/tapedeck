//
//  Utterance.swift
//  TapeDeck
//
//	 A single chunk of transcribed speech. Apple's engines provide no speaker
//	 diarization; `speaker` exists so other engines (or future APIs) can fill it in.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

public struct Utterance: Codable, Sendable, Equatable, Identifiable {
	public var id: UUID
	public var text: String
	public var timeRange: Range<TimeInterval>?
	public var confidence: Double
	public var speaker: String?
	public var isFinal: Bool

	public init(id: UUID = UUID(), text: String, timeRange: Range<TimeInterval>? = nil, confidence: Double = 0, speaker: String? = nil, isFinal: Bool = false) {
		self.id = id
		self.text = text
		self.timeRange = timeRange
		self.confidence = confidence
		self.speaker = speaker
		self.isFinal = isFinal
	}
}
