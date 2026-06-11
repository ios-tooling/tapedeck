//
//  BarMeter.swift
//  TapeDeck
//
//	 A horizontal segmented level bar with gradient coloring and peak hold.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

struct BarMeter: View {
	let palette: MeterPalette
	let segmentCount = 28

	@State private var driver = MeterDriver(count: 1)

	var body: some View {
		Canvas { context, size in
			draw(in: &context, size: size)
		}
		.onAppear {
			driver.peakDecayPerSecond = 0.42
			driver.targetProvider = { [Microphone.instance.normalizedLevel] }
			driver.start()
		}
		.onDisappear { driver.stop() }
	}

	private func draw(in context: inout GraphicsContext, size: CGSize) {
		let level = driver.values[0]
		let peak = driver.peaks[0]
		let cellWidth = size.width / Double(segmentCount)
		let segmentWidth = max(2, cellWidth * 0.78)
		let segmentHeight = max(8, min(size.height * 0.55, 56))
		let cornerRadius = min(segmentWidth, segmentHeight) * 0.3
		let centerY = size.height / 2

		let litSegments = Int((level * Double(segmentCount)).rounded())
		let peakSegment = Int((peak * Double(segmentCount)).rounded(.up))

		for index in 0..<segmentCount {
			let centerX = (Double(index) + 0.5) * cellWidth
			let fraction = Double(index) / Double(max(1, segmentCount - 1))
			let isLit = index < litSegments
			let isPeak = peakSegment > litSegments && index == peakSegment - 1
			let color = palette.ledColor(forFraction: fraction, lit: isLit || isPeak, peak: isPeak)
			let rect = CGRect(x: centerX - segmentWidth / 2, y: centerY - segmentHeight / 2, width: segmentWidth, height: segmentHeight)

			context.fill(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(color))
		}
	}
}
