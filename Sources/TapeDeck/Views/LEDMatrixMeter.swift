//
//  LEDMatrixMeter.swift
//  TapeDeck
//
//	 A dot-matrix LED meter: columns of recent history mirrored above and below
//	 a centerline, with decaying peak dots.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

struct LEDMatrixMeter: View {
	let palette: MeterPalette
	let columnCount = 22
	let dotsPerHalf = 7

	@State private var driver = MeterDriver(count: 22)

	var body: some View {
		Canvas { context, size in
			draw(in: &context, size: size)
		}
		.onAppear {
			driver.targetProvider = { [columnCount] in
				let mic = Microphone.instance
				let tail = mic.history.recent(columnCount).map { $0.level.normalized(floor: mic.noiseFloor) }
				return Array(repeating: 0, count: max(0, columnCount - tail.count)) + tail
			}
			driver.start()
		}
		.onDisappear { driver.stop() }
	}

	private func draw(in context: inout GraphicsContext, size: CGSize) {
		let totalRows = dotsPerHalf * 2
		let cellWidth = size.width / Double(columnCount)
		let cellHeight = size.height / Double(totalRows)
		let dotSize = max(2, min(cellWidth, cellHeight) * 0.72)
		let cornerRadius = dotSize * 0.32
		let centerY = size.height / 2

		var divider = Path()
		divider.move(to: CGPoint(x: 0, y: centerY))
		divider.addLine(to: CGPoint(x: size.width, y: centerY))
		context.stroke(divider, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)

		for column in 0..<columnCount {
			let level = driver.values[column]
			let peak = driver.peaks[column]
			let litRows = Int((level * Double(dotsPerHalf)).rounded())
			let peakRow = Int((peak * Double(dotsPerHalf)).rounded(.up))
			let centerX = (Double(column) + 0.5) * cellWidth

			for half in 0..<2 {
				for row in 0..<dotsPerHalf {
					let direction: Double = half == 0 ? -1 : 1
					let y = centerY + direction * (Double(row) + 0.5) * cellHeight
					let rect = CGRect(x: centerX - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
					let rowFraction = Double(row) / Double(max(1, dotsPerHalf - 1))
					let isLit = row < litRows
					let isPeak = peakRow > litRows && row == peakRow - 1
					let color = palette.ledColor(forFraction: rowFraction, lit: isLit || isPeak, peak: isPeak)

					context.fill(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(color))
				}
			}
		}
	}
}
