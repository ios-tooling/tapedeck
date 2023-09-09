//
//  RecordingLevelsView.swift
//
//
//  Created by Ben Gottlieb on 9/8/23.
//

import SwiftUI

public struct RecordingLevelsView: View {
	let samples: [Transcript.SoundLevel]
	
	public init(resolution: Int = 300, recording: SavedRecording, recent: Bool = false) {
		if recent {
			samples = recording.transcript?.soundLevels.suffix(resolution) ?? []
		} else {
			samples = recording.transcript?.soundLevels.downSampled(to: resolution) ?? []
		}
	}
	
	public var body: some View {
		HStack(spacing: 0) {
			ForEach(samples.indices, id: \.self) { idx in
				Bar(volume: samples[idx].level)
			}
			Spacer()
		}
	}
	
	struct Bar: View {
		let volume: Double
		
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

						Spacer(minLength: 0)
					}
					//.background(Color.green)
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
