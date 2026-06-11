//
//  MeterPalette.swift
//  TapeDeck
//
//	 Colors for the AmbientSoundView meter styles, keyed by loudness.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

public struct MeterPalette: Sendable {
	public var quiet: Color
	public var mid: Color
	public var loud: Color

	public init(quiet: Color, mid: Color, loud: Color) {
		self.quiet = quiet
		self.mid = mid
		self.loud = loud
	}

	public static let standard = MeterPalette(quiet: .green, mid: .yellow, loud: .red)
	public static let siri = MeterPalette(quiet: .teal, mid: .indigo, loud: .orange)

	func color(forFraction fraction: Double) -> Color {
		switch fraction {
		case ..<0.45: quiet
		case ..<0.78: mid
		default: loud
		}
	}

	func ledColor(forFraction fraction: Double, lit: Bool, peak: Bool) -> Color {
		let base = color(forFraction: fraction)
		if peak { return base }
		return base.opacity(lit ? 0.92 : 0.085)
	}
}
