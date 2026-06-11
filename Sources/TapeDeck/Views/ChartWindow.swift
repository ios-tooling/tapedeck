//
//  ChartWindow.swift
//  TapeDeck
//
//	 A normalized visible window over a full timeline, expressed as fractions in 0...1.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

struct ChartWindow: Equatable {
	var start: Double
	var end: Double

	static let full = ChartWindow(start: 0, end: 1)
	static let minSpan = 0.04									// ~25× max zoom

	var span: Double { max(end - start, ChartWindow.minSpan) }
	var center: Double { (start + end) / 2 }

	// a window of the given span centered on `center`, clamped to 0...1
	static func centered(on center: Double, span: Double) -> ChartWindow {
		let span = min(max(span, minSpan), 1)
		var low = center - span / 2
		var high = center + span / 2

		if low < 0 {
			high -= low
			low = 0
		}
		if high > 1 {
			low -= high - 1
			high = 1
		}
		return ChartWindow(start: max(0, low), end: min(1, high))
	}

	// shifts the window by a fractional delta, clamped so it stays within 0...1
	func shifted(by delta: Double) -> ChartWindow {
		let span = span
		var low = start + delta

		if low < 0 { low = 0 }
		if low + span > 1 { low = 1 - span }
		return ChartWindow(start: low, end: low + span)
	}
}
