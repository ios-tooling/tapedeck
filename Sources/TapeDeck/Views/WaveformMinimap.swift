//
//  WaveformMinimap.swift
//  TapeDeck
//
//	 A full-recording overview strip: the whole waveform, a box marking the
//	 zoomed-in window above, and a playhead. Dragging recenters the window.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

struct WaveformMinimap: View {
	let samples: [Float]
	let playhead: Double?
	let window: ChartWindow
	let tint: Color
	let onMove: (Double) -> Void

	var body: some View {
		GeometryReader { proxy in
			let width = proxy.size.width
			let height = proxy.size.height

			ZStack(alignment: .topLeading) {
				sparkline(width: width, height: height)
				WindowBox(window: window, width: width, height: height)
				PlayheadLine(fraction: playhead.map { CGFloat(min(max($0, 0), 1)) }, height: height, width: width)
			}
			.clipShape(RoundedRectangle(cornerRadius: 8))
			.background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
			.contentShape(Rectangle())
			.gesture(
				DragGesture(minimumDistance: 0).onChanged { drag in
					onMove(max(0, min(1, Double(drag.location.x / max(1, width)))))
				}
			)
		}
	}

	private func sparkline(width: CGFloat, height: CGFloat) -> some View {
		Path { path in
			guard samples.count > 1 else { return }

			path.move(to: CGPoint(x: 0, y: height))
			for (index, value) in samples.enumerated() {
				let x = CGFloat(index) / CGFloat(samples.count - 1) * width
				let y = (1 - CGFloat(min(max(value, 0), 1))) * height
				path.addLine(to: CGPoint(x: x, y: y))
			}
			path.addLine(to: CGPoint(x: width, y: height))
			path.closeSubpath()
		}
		.fill(tint.opacity(0.35))
	}
}

private struct WindowBox: View {
	let window: ChartWindow
	let width: CGFloat
	let height: CGFloat

	var body: some View {
		if window != .full {
			let x = CGFloat(window.start) * width
			let boxWidth = max(6, CGFloat(window.span) * width)

			RoundedRectangle(cornerRadius: 4)
				.strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
				.background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
				.frame(width: boxWidth, height: height)
				.position(x: x + boxWidth / 2, y: height / 2)
		}
	}
}
