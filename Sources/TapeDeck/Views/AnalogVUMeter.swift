//
//  AnalogVUMeter.swift
//  TapeDeck
//
//	 A classic needle-on-dial VU meter: arc scale with tick marks, a red zone
//	 at the top of the range, and a needle with analog-style ballistics.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

struct AnalogVUMeter: View {
	let palette: MeterPalette

	// dial sweep, in radians from vertical
	private let sweep = Angle(degrees: 50)
	private let redZoneStart = 0.75

	@State private var driver = MeterDriver(count: 1)

	var body: some View {
		Canvas { context, size in
			draw(in: &context, size: size)
		}
		.onAppear {
			driver.attackBlend = 0.3								// needle inertia
			driver.releaseBlend = 0.12
			driver.targetProvider = { [Microphone.instance.normalizedLevel] }
			driver.start()
		}
		.onDisappear { driver.stop() }
	}

	private func draw(in context: inout GraphicsContext, size: CGSize) {
		let pivot = CGPoint(x: size.width / 2, y: size.height * 0.95)
		let radius = min(size.width / 2, size.height * 0.85)

		drawScale(in: &context, pivot: pivot, radius: radius)
		drawNeedle(in: &context, pivot: pivot, radius: radius, level: driver.values[0])

		let hub = CGRect(x: pivot.x - radius * 0.04, y: pivot.y - radius * 0.04, width: radius * 0.08, height: radius * 0.08)
		context.fill(Path(ellipseIn: hub), with: .color(.primary))
	}

	private func angle(for fraction: Double) -> Double {
		(-sweep.radians) + fraction * (2 * sweep.radians) - .pi / 2
	}

	private func point(at fraction: Double, radius: Double, pivot: CGPoint) -> CGPoint {
		let angle = angle(for: fraction)
		return CGPoint(x: pivot.x + cos(angle) * radius, y: pivot.y + sin(angle) * radius)
	}

	private func drawScale(in context: inout GraphicsContext, pivot: CGPoint, radius: Double) {
		var arc = Path()
		arc.addArc(center: pivot, radius: radius * 0.82,
					  startAngle: .radians(angle(for: 0)), endAngle: .radians(angle(for: redZoneStart)), clockwise: false)
		context.stroke(arc, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

		var redArc = Path()
		redArc.addArc(center: pivot, radius: radius * 0.82,
						  startAngle: .radians(angle(for: redZoneStart)), endAngle: .radians(angle(for: 1)), clockwise: false)
		context.stroke(redArc, with: .color(palette.loud), style: StrokeStyle(lineWidth: 3, lineCap: .round))

		let tickCount = 10
		for tick in 0...tickCount {
			let fraction = Double(tick) / Double(tickCount)
			let isMajor = tick % 2 == 0
			let inner = point(at: fraction, radius: radius * (isMajor ? 0.72 : 0.76), pivot: pivot)
			let outer = point(at: fraction, radius: radius * 0.80, pivot: pivot)

			var tickPath = Path()
			tickPath.move(to: inner)
			tickPath.addLine(to: outer)

			let color: Color = fraction >= redZoneStart ? palette.loud : .secondary
			context.stroke(tickPath, with: .color(color), lineWidth: isMajor ? 2 : 1)
		}
	}

	private func drawNeedle(in context: inout GraphicsContext, pivot: CGPoint, radius: Double, level: Double) {
		let tip = point(at: level, radius: radius * 0.78, pivot: pivot)

		var needle = Path()
		needle.move(to: pivot)
		needle.addLine(to: tip)
		context.stroke(needle, with: .color(palette.color(forFraction: level)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
	}
}
