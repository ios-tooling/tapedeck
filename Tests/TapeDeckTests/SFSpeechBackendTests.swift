//
//  SFSpeechBackendTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/6/26.
//

import Testing
import Foundation
@testable import TapeDeck

@MainActor struct SFSpeechBackendTests {
	@Test func onDeviceUnavailabilityIsClassified() {
		// the "Siri and Dictation are disabled" refusal
		let localRecognitionError = NSError(domain: "kLSRErrorDomain", code: 201)
		#expect(SFSpeechBackend.indicatesOnDeviceRecognitionUnavailable(localRecognitionError))

		// ordinary speech errors must not trigger the server fallback
		let noSpeechError = NSError(domain: "kAFAssistantErrorDomain", code: 1110)
		#expect(!SFSpeechBackend.indicatesOnDeviceRecognitionUnavailable(noSpeechError))
	}
}
