//
//  AmbientWaveformView.swift
//
//
//  Created by Ben Gottlieb on 9/7/23.
//

import Suite

public extension Color {
	static let siriPurple = Color(hex: 0x5A28D1)
}

#if os(iOS)
@available(iOS 15.0, *)
public struct AmbientWaveformView : View {
	@ObservedObject var history = Microphone.instance.history
	@ObservedObject var mic = Microphone.instance
	
	public init(showWhenMicrophoneOff: Bool = false, waveColors: [ForegroundStyle] = [], lineWidth: Double = 0.5) {
		self.showWhenMicrophoneOff = showWhenMicrophoneOff
		self.lineWidth = lineWidth
		self.waveColors = waveColors
	}
	
	var frequency: CGFloat = 1.5
	var idleAmplitude: CGFloat = 0.01
	var phaseShift: CGFloat = -0.15
	var density: CGFloat = 1.0
	var numberOfWaves = 3
	var waveColors: [ForegroundStyle]
	let showWhenMicrophoneOff: Bool
	let lineWidth: Double
		
	@State var amplitude: CGFloat = 1.0
	@State var phase:CGFloat = 0.0
	let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

	struct SingleWave: Shape {
		let index: Int
		let normedAmplitude: CGFloat
		var density: CGFloat = 1.0
		var frequency: CGFloat = 1.5
		var phase:CGFloat = 0.0
		
		func path(in rect: CGRect) -> Path {
			var path = Path()
			let mid = rect.width / 2.0
			let maxAmplitude = rect.height / 2 - 4

			for x in stride(from: 0, to: rect.width + density, by: density) {
				let scaling = -pow(1 / mid * (x - mid), 2) + 1
				let y = scaling * maxAmplitude * normedAmplitude * sin(CGFloat(2.0 * .pi) * frequency * (x / rect.width)  + phase) + rect.height/2.0
				if x == 0 {
					path.move(to: CGPoint(x: x, y: y))
				} else {
					path.addLine(to: CGPoint(x: x, y: y))
				}
			}
			return path
		}
		
	}

	public var body: some View {
		if showWhenMicrophoneOff || !history.isEmpty {
			ZStack {
				ForEach(0..<numberOfWaves, id: \.self) { waveIndex in
					let progress = 1.0 - CGFloat(waveIndex) / CGFloat(self.numberOfWaves)
					let normedAmplitude = ((1.5 * progress - 0.8) * self.amplitude) * (mic.isListening ? 1 : 0.05)
					let fraction = Double(self.numberOfWaves - waveIndex)
					let waveColor = waveColors.isEmpty ? ForegroundStyle.foreground : waveColors[waveIndex % waveColors.count]
					
					SingleWave(index: waveIndex, normedAmplitude: normedAmplitude, density: density, frequency: frequency, phase: phase)
						.stroke(waveColor.opacity(fraction / Double(numberOfWaves)), style: .init(lineWidth: lineWidth * fraction, lineCap: .round, lineJoin: .round))
					
				}
				.onReceive(timer) { _ in
					amplitude = history.currentNormalizedLevel
					phase += phaseShift
				}
			}
		}
	}
}
#endif
