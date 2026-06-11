//
//  AmbientSoundView.swift
//  TapeDeck
//
//	 A view to show the current audio levels in the nearby area. Different styles available
//	 - analog vu meter
//	 - digital vu meter (LED matrix or segmented bar)
//	 - 'siri-like' wave display
//
//	 By default it starts the Microphone while visible (and stops it again if it
//	 was the one that started it).
//
//  Created by Ben Gottlieb on 6/11/26.
//

import SwiftUI

public struct AmbientSoundView: View {
	public enum Style: String, CaseIterable, Sendable {
		case siriWave, ledMatrix, bar, analogVU
	}

	let style: Style
	let palette: MeterPalette
	let autoStarts: Bool

	@State private var isMonitoring = false

	public init(style: Style = .siriWave, palette: MeterPalette? = nil, autoStarts: Bool = true) {
		self.style = style
		self.palette = palette ?? (style == .siriWave ? .siri : .standard)
		self.autoStarts = autoStarts
	}

	public var body: some View {
		Group {
			switch style {
			case .siriWave: SiriWaveMeter(palette: palette)
			case .ledMatrix: LEDMatrixMeter(palette: palette)
			case .bar: BarMeter(palette: palette)
			case .analogVU: AnalogVUMeter(palette: palette)
			}
		}
		.opacity(Microphone.instance.isListening ? 1 : 0.35)
		.task {
			guard autoStarts else { return }
			if (try? await Microphone.instance.beginMonitoring()) != nil { isMonitoring = true }
		}
		.onDisappear {
			if isMonitoring {
				isMonitoring = false
				Microphone.instance.endMonitoring()
			}
		}
	}
}
