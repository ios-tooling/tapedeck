//
//  SiriWaveMeter.swift
//  TapeDeck
//
//	 Three overlapping animated sine waves whose amplitude tracks the live
//	 level — a Siri-style ambient display.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

struct SiriWaveMeter: View {
	let palette: MeterPalette

	@State private var animationStartedAt = Date()
	@State private var displayedLevel: Double = 0

	var body: some View {
		let target = targetLevel

		TimelineView(.animation(minimumInterval: 1 / 60)) { context in
			WaveCanvas(palette: palette, phase: context.date.timeIntervalSince(animationStartedAt), level: displayedLevel)
		}
		.onAppear {
			displayedLevel = target
			animationStartedAt = Date()
		}
		.onChange(of: target) { _, newLevel in
			let animation: Animation = newLevel >= displayedLevel ? .linear(duration: 0.02) : .easeOut(duration: 0.07)
			withAnimation(animation) { displayedLevel = newLevel }
		}
	}

	private var targetLevel: Double {
		let mic = Microphone.instance
		let latest = mic.normalizedLevel
		let recent = mic.history.recent(3).map { $0.level.normalized(floor: mic.noiseFloor) }
		guard !recent.isEmpty else { return latest }

		let average = recent.reduce(0, +) / Double(recent.count)
		return min(1, max(latest, average * 0.42))
	}
}

private struct WaveCanvas: View, Animatable {
	let palette: MeterPalette
	var phase: Double
	var level: Double

	private let pointCount = 160

	nonisolated var animatableData: Double {
		get { level }
		set { level = newValue }
	}

	private struct WaveLayer {
		let amplitude: Double
		let frequency: Double
		let speed: Double
		let phaseOffset: Double
		let lineWidth: CGFloat
		let opacity: Double
	}

	private static let layers = [
		WaveLayer(amplitude: 0.38, frequency: 2.1, speed: 1.65, phaseOffset: 0, lineWidth: 4.2, opacity: 0.95),
		WaveLayer(amplitude: 0.25, frequency: 3.2, speed: -1.15, phaseOffset: 1.4, lineWidth: 2.6, opacity: 0.62),
		WaveLayer(amplitude: 0.14, frequency: 4.6, speed: 0.82, phaseOffset: 2.7, lineWidth: 1.6, opacity: 0.42),
	]

	var body: some View {
		Canvas { context, size in
			drawBaseline(in: &context, size: size)
			drawWaves(in: &context, size: size)
		}
	}

	private func drawBaseline(in context: inout GraphicsContext, size: CGSize) {
		var baseline = Path()
		baseline.move(to: CGPoint(x: 0, y: size.height / 2))
		baseline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
		context.stroke(baseline, with: .color(palette.mid.opacity(0.18)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
	}

	private func drawWaves(in context: inout GraphicsContext, size: CGSize) {
		let amplitudeScale = pow(min(max(level, 0), 1), 1.28)

		for layer in Self.layers {
			let path = wavePath(size: size, scale: amplitudeScale, layer: layer)
			let loudOpacity = min(0.72, max(0, (level - 0.48) * 1.4))
			let shading = GraphicsContext.Shading.linearGradient(
				Gradient(colors: [
					palette.quiet.opacity(layer.opacity),
					palette.mid.opacity(layer.opacity),
					palette.loud.opacity(layer.opacity * loudOpacity + layer.opacity * 0.25),
				]),
				startPoint: .zero,
				endPoint: CGPoint(x: size.width, y: 0)
			)
			context.stroke(path, with: shading, style: StrokeStyle(lineWidth: layer.lineWidth, lineCap: .round, lineJoin: .round))
		}
	}

	private func wavePath(size: CGSize, scale: Double, layer: WaveLayer) -> Path {
		var path = Path()
		let centerY = size.height / 2

		for index in 0..<pointCount {
			let progress = Double(index) / Double(pointCount - 1)
			let x = CGFloat(progress) * size.width
			let edgeTaper = 0.18 + 0.82 * sin(.pi * progress)
			let contour = contour(at: progress, layer: layer)
			let amplitude = (0.004 + scale * layer.amplitude * contour) * Double(size.height) * edgeTaper
			let primary = sin(progress * layer.frequency * 2 * .pi + phase * layer.speed + layer.phaseOffset)
			let harmonic = sin(progress * layer.frequency * 3.46 * .pi - phase * layer.speed * 0.46 + layer.phaseOffset * 1.7) * 0.28
			let point = CGPoint(x: x, y: centerY + CGFloat((primary + harmonic) * amplitude))

			if index == 0 {
				path.move(to: point)
			} else {
				path.addLine(to: point)
			}
		}
		return path
	}

	private func contour(at progress: Double, layer: WaveLayer) -> Double {
		let first = sin(progress * 2 * .pi * 1.35 + layer.phaseOffset * 0.8) * 0.16
		let second = sin(progress * 2 * .pi * 2.75 - layer.phaseOffset * 1.4) * 0.10
		return min(max(0.74 + first + second, 0), 1)
	}
}
