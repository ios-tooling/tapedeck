//
//  WaveformDetailView.swift
//  TapeDeck
//
//	 Zoomable PCM waveform for the visible window. Pinch zooms, one-finger drag
//	 scrubs, tap seeks, double-tap resets zoom.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

struct WaveformDetailView: View {
	let peaks: [Float]
	@Binding var window: ChartWindow
	let duration: TimeInterval
	let playhead: TimeInterval?
	let tint: Color
	let onSeek: (TimeInterval) -> Void

	@State private var zoomBase: ChartWindow?

	private var visibleStart: TimeInterval { window.start * duration }
	private var visibleSpan: TimeInterval { max(window.span * duration, 0.001) }

	var body: some View {
		GeometryReader { proxy in
			let width = proxy.size.width
			let height = proxy.size.height

			ZStack {
				Canvas { context, size in
					draw(context, size: size)
				}
				PlayheadLine(fraction: playheadFraction, height: height, width: width)
			}
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
			.contentShape(Rectangle())
			.gesture(magnify)
			.gesture(scrubGesture(width: width))
			.onTapGesture(count: 2) { window = .full }
			.onTapGesture { location in
				onSeek(time(atX: location.x, width: width))
			}
		}
	}

	private var playheadFraction: CGFloat? {
		guard let playhead, duration > 0 else { return nil }
		let fraction = CGFloat((playhead - visibleStart) / visibleSpan)
		return (0...1).contains(fraction) ? fraction : nil
	}

	private func draw(_ context: GraphicsContext, size: CGSize) {
		guard peaks.count > 1 else { return }

		let middle = size.height / 2
		var path = Path()

		for (index, peak) in peaks.enumerated() {
			let x = CGFloat(index) / CGFloat(peaks.count - 1) * size.width
			let half = CGFloat(min(max(peak, 0), 1)) * (size.height / 2 - 2)
			path.move(to: CGPoint(x: x, y: middle - half))
			path.addLine(to: CGPoint(x: x, y: middle + half))
		}
		context.stroke(path, with: .color(tint), lineWidth: 1)
	}

	private func time(atX x: CGFloat, width: CGFloat) -> TimeInterval {
		visibleStart + Double(max(0, min(1, x / max(1, width)))) * visibleSpan
	}

	private var magnify: some Gesture {
		MagnifyGesture()
			.onChanged { value in
				let base = zoomBase ?? window
				if zoomBase == nil { zoomBase = base }
				window = ChartWindow.centered(on: base.center, span: base.span / max(Double(value.magnification), 0.0001))
			}
			.onEnded { _ in zoomBase = nil }
	}

	private func scrubGesture(width: CGFloat) -> some Gesture {
		DragGesture(minimumDistance: 6)
			.onChanged { value in
				if window == .full {
					onSeek(time(atX: value.location.x, width: width))
				} else {
					// while zoomed, dragging pans the window
					let delta = Double((value.translation.width - lastTranslation) / max(1, width)) * window.span
					window = window.shifted(by: -delta)
					lastTranslation = value.translation.width
				}
			}
			.onEnded { _ in lastTranslation = 0 }
	}

	@State private var lastTranslation: CGFloat = 0
}

struct PlayheadLine: View {
	let fraction: CGFloat?
	let height: CGFloat
	let width: CGFloat

	var body: some View {
		if let fraction {
			Rectangle()
				.fill(.white)
				.frame(width: 1.5, height: height)
				.position(x: fraction * width, y: height / 2)
		}
	}
}
