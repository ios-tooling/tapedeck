//
//  AudioLevel.swift
//  TapeDeck
//
//	 A single audio level measurement: decibels (dBFS, ≤ 0) plus a 0–1 value
//	 normalized against a noise floor.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation
import AVFoundation
import Accelerate

public struct AudioLevel: Sendable, Codable, Equatable {
	public static let defaultNoiseFloor = -80.0
	public static let silent = AudioLevel(decibels: -160)

	public let decibels: Double

	public init(decibels: Double) {
		self.decibels = decibels
	}

	public var normalized: Double { normalized(floor: Self.defaultNoiseFloor) }

	public func normalized(floor: Double) -> Double {
		guard floor < 0 else { return 0 }
		let clamped = min(max(decibels, floor), 0)
		return (clamped - floor) / abs(floor)
	}
}

extension AudioLevel {
	init(buffer: AVAudioPCMBuffer) {
		self.init(decibels: AudioLevel.decibels(rms: Self.rms(of: buffer)))
	}

	static func decibels(rms: Double) -> Double {
		guard rms > 0 else { return AudioLevel.silent.decibels }
		return 20 * log10(rms)
	}

	static func rms(of buffer: AVAudioPCMBuffer) -> Double {
		let frames = vDSP_Length(buffer.frameLength)
		guard frames > 0 else { return 0 }

		if let channels = buffer.floatChannelData {
			var rms: Float = 0
			vDSP_rmsqv(channels[0], 1, &rms, frames)
			return Double(rms)
		}

		if let channels = buffer.int16ChannelData {
			var floats = [Float](repeating: 0, count: Int(frames))
			vDSP_vflt16(channels[0], 1, &floats, 1, frames)
			var rms: Float = 0
			vDSP_rmsqv(floats, 1, &rms, frames)
			return Double(rms) / Double(Int16.max)
		}

		return 0
	}
}
