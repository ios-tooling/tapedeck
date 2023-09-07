//
//  SoundLevelsView.swift
//
//
//  Created by Ben Gottlieb on 9/7/23.
//

import SwiftUI

public struct SoundLevelsView: View {
	@ObservedObject var history = Microphone.instance.history
	
	public init() { }
	
	public var body: some View {
		let bars = history.recent(10)
		
		HStack(spacing: 2) {
			ForEach(bars.indices, id: \.self) { idx in
				Bar(volume: bars[idx])
			}
		}
	}
	
	struct Bar: View {
		let volume: Volume
		
		var body: some View {
			ZStack {
				Color.black
			}
			.overlay(
				GeometryReader { geo in
					VStack(spacing: 0) {
						Spacer(minLength: 0)
						
						Rectangle()
							.fill(.red)
							.frame(width: 10, height: geo.height * (volume.unit * volume.unit))

						Spacer(minLength: 0)
					}
					//.background(Color.green)
				}
			)
		}
	}
}

#Preview {
	SoundLevelsView()
}
