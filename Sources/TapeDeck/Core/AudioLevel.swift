//
//  AudioLevel.swift
//  TapeDeck
//
//	 A single audio level measurement: average (RMS) and peak decibels (dBFS, ≤ 0),
//	 each with a 0–1 value normalized against a noise floor.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation
import AVFoundation
import Accelerate

public struct AudioLevel: Sendable, Codable, Equatable {
	public static let defaultNoiseFloor = -80.0
	public static let silent = AudioLevel(decibels: -160, peak: -160)

	public let decibels: Double		// average (RMS) power, dBFS
	public let peak: Double			// peak power, dBFS

	public init(decibels: Double, peak: Double) {
		self.decibels = decibels
		self.peak = peak
	}

	// back-compat: a level with no distinct peak treats peak as equal to the average
	public init(decibels: Double) {
		self.init(decibels: decibels, peak: decibels)
	}

	// peak is optional on decode so manifests written before peak existed still load
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let decibels = try container.decode(Double.self, forKey: .decibels)
		self.decibels = decibels
		self.peak = try container.decodeIfPresent(Double.self, forKey: .peak) ?? decibels
	}

	public var normalized: Double { normalized(floor: Self.defaultNoiseFloor) }
	public func normalized(floor: Double) -> Double { Self.normalize(decibels, floor: floor) }

	public var normalizedPeak: Double { normalizedPeak(floor: Self.defaultNoiseFloor) }
	public func normalizedPeak(floor: Double) -> Double { Self.normalize(peak, floor: floor) }

	private static func normalize(_ value: Double, floor: Double) -> Double {
		guard floor < 0 else { return 0 }
		let clamped = min(max(value, floor), 0)
		return (clamped - floor) / abs(floor)
	}
}

extension AudioLevel {
	init(buffer: AVAudioPCMBuffer) {
		let measured = Self.measure(buffer)
		self.init(decibels: Self.decibels(magnitude: measured.rms), peak: Self.decibels(magnitude: measured.peak))
	}

	static func decibels(magnitude: Double) -> Double {
		guard magnitude > 0 else { return AudioLevel.silent.decibels }
		return 20 * log10(magnitude)
	}

	// returns linear (0–1) RMS and peak magnitudes in a single pass over channel 0
	static func measure(_ buffer: AVAudioPCMBuffer) -> (rms: Double, peak: Double) {
		let frames = vDSP_Length(buffer.frameLength)
		guard frames > 0 else { return (0, 0) }

		if let channels = buffer.floatChannelData {
			var rms: Float = 0
			var peak: Float = 0
			vDSP_rmsqv(channels[0], 1, &rms, frames)
			vDSP_maxmgv(channels[0], 1, &peak, frames)
			return (Double(rms), Double(peak))
		}

		if let channels = buffer.int16ChannelData {
			var floats = [Float](repeating: 0, count: Int(frames))
			vDSP_vflt16(channels[0], 1, &floats, 1, frames)
			var rms: Float = 0
			var peak: Float = 0
			vDSP_rmsqv(floats, 1, &rms, frames)
			vDSP_maxmgv(floats, 1, &peak, frames)
			let scale = Double(Int16.max)
			return (Double(rms) / scale, Double(peak) / scale)
		}

		return (0, 0)
	}
}
