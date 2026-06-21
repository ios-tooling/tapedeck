//
//  WaveformBars.swift
//  TapeDeck
//
//	 The bar-waveform *shape*: a row of rounded bars mirrored about the vertical
//	 centerline, one per normalized (0...1) level. Purely a renderer — feed it
//	 live mic levels for a recording meter, or a file's peak envelope for a
//	 static waveform. The bars size themselves to fill the view's width.
//
//  Created by Ben Gottlieb on 6/17/26.
//

import SwiftUI

public struct WaveformBars: View {
	let levels: [Double]
	let tint: Color
	let progress: Double?
	let progressTint: Color
	let spacing: CGFloat
	let maxBarWidth: CGFloat

	/// `progress` (0...1), when set, tints the bars up to that fraction with `progressTint`
	/// — e.g. a playback position indicator.
	public init(levels: [Double], tint: Color = .accentColor, progress: Double? = nil, progressTint: Color? = nil, spacing: CGFloat = 2, maxBarWidth: CGFloat = 3) {
		self.levels = levels
		self.tint = tint
		self.progress = progress
		self.progressTint = progressTint ?? tint
		self.spacing = spacing
		self.maxBarWidth = maxBarWidth
	}

	public var body: some View {
		GeometryReader { proxy in
			let count = max(levels.count, 1)
			// Fill the width, but never let a bar balloon into a blob when there are
			// only a few samples — cap the width and let the row center itself.
			let fillWidth = (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
			let barWidth = max(1, min(maxBarWidth, fillWidth))

			HStack(alignment: .center, spacing: spacing) {
				ForEach(levels.indices, id: \.self) { index in
					Capsule()
						.fill(color(for: index))
						.frame(width: barWidth, height: height(for: levels[index], in: proxy.size.height, barWidth: barWidth))
				}
			}
			.frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
		}
	}

	private func color(for index: Int) -> Color {
		guard let progress else { return tint }
		let fraction = Double(index) / Double(max(levels.count - 1, 1))
		return fraction <= progress ? progressTint : tint
	}

	// Centered in the HStack, a bar of `level * height` extends equally above and
	// below the midline. A silent bar collapses to a dot (a bar-width tall capsule).
	private func height(for level: Double, in maxHeight: CGFloat, barWidth: CGFloat) -> CGFloat {
		let clamped = min(max(level, 0), 1)
		return max(barWidth, CGFloat(clamped) * maxHeight)
	}
}
