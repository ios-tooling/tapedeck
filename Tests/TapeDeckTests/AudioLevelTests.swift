//
//  AudioLevelTests.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Testing
import AVFoundation
@testable import TapeDeck

struct AudioLevelTests {
	@Test func decibelsFromRMS() {
		#expect(abs(AudioLevel.decibels(rms: 1.0)) < 0.0001)								// full scale → 0 dB
		#expect(abs(AudioLevel.decibels(rms: 0.5) - -6.0206) < 0.001)					// half scale → ≈ -6 dB
		#expect(AudioLevel.decibels(rms: 0) == AudioLevel.silent.decibels)			// silence clamps, no -inf
	}

	@Test func normalizedMapsFloorToZeroAndFullScaleToOne() {
		#expect(AudioLevel(decibels: 0).normalized == 1)
		#expect(AudioLevel(decibels: -80).normalized == 0)
		#expect(AudioLevel(decibels: -200).normalized == 0)								// below the floor clamps
		#expect(abs(AudioLevel(decibels: -40).normalized - 0.5) < 0.0001)
	}

	@Test func normalizedRespectsCustomFloor() {
		#expect(abs(AudioLevel(decibels: -20).normalized(floor: -40) - 0.5) < 0.0001)
		#expect(AudioLevel(decibels: -10).normalized(floor: 0) == 0)					// degenerate floor is safe
	}

	@Test func rmsOfConstantAmplitudeBuffer() throws {
		let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
		let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
		buffer.frameLength = 1024

		let samples = try #require(buffer.floatChannelData)
		for index in 0..<1024 { samples[0][index] = 0.5 }

		#expect(abs(AudioLevel.rms(of: buffer) - 0.5) < 0.0001)
		#expect(abs(AudioLevel(buffer: buffer).decibels - -6.0206) < 0.001)
	}

	@Test func emptyBufferIsSilent() throws {
		let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
		let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))

		#expect(AudioLevel.rms(of: buffer) == 0)
		#expect(AudioLevel(buffer: buffer).normalized == 0)
	}
}
