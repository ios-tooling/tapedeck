//
//  RecordingLevelsView.swift
//
//
//  Created by Ben Gottlieb on 9/8/23.
//

import SwiftUI

public struct RecordingLevelsView: View {
	let samples: [Transcript.SoundLevel]
	let bottomAligned: Bool
	
	public init(resolution: Int = 300, recording: SavedRecording, recent: Bool = false, bottomAligned: Bool = false) {
		if recent {
			samples = recording.transcript?.soundLevels.suffix(resolution) ?? []
		} else {
			samples = recording.transcript?.soundLevels.downSampled(to: resolution) ?? []
		}
		self.bottomAligned = bottomAligned
	}
	
	public var body: some View {
		HStack(spacing: 0) {
			ForEach(samples.indices, id: \.self) { idx in
				Bar(volume: samples[idx].level, bottomAligned: bottomAligned)
			}
			Spacer()
		}
	}
	
	struct Bar: View {
		let volume: Double
		let bottomAligned: Bool
		
		var body: some View {
			ZStack {
				Color.clear
			}
			.overlay(
				GeometryReader { geo in
					VStack(spacing: 0) {
						Spacer(minLength: 0)
						
						Rectangle()
							.fill(Color.red)
							.frame(height: geo.height * pow(volume, 4))

						if !bottomAligned { Spacer(minLength: 0) }
					}
				}
			)
			.frame(maxWidth: 2)
		}
	}

}

extension Array {
	func downSampled(to requested: Int) -> [Element] {
		if count < requested { return self }
		
		let stepSize = Double(count) / Double(requested)
		var position = 0.0
		var results: [Element] = []
		var lastPosition: Int?
		
		while position < Double(count) {
			let intPosition = Int(position)
			if intPosition != lastPosition {
				results.append(self[intPosition])
				lastPosition = intPosition
			}
			position += stepSize
		}
		
		return results
	}
}
