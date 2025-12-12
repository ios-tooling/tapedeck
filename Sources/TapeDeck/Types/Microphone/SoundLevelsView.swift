//
//  SoundLevelsView.swift
//
//
//  Created by Ben Gottlieb on 9/7/23.
//

#if os(iOS)
import SwiftUI

public struct SoundLevelsView: View {
	@ObservedObject var history = Microphone.instance.history
	let bottomAligned: Bool
	let showSpacer: Bool

	public init(bottomAligned: Bool = false, showSpacers: Bool = false) {
		self.bottomAligned = bottomAligned
		self.showSpacer = showSpacers
	}
	
	public var body: some View {
		let bars = history.recent(500)
		
		HStack(spacing: 0) {
			ForEach(bars.indices, id: \.self) { idx in
				Bar(volume: bars[idx], bottomAligned: bottomAligned, showSpacer: showSpacer)
			}
		}
		.ignoresSafeArea()
	}
	
	struct Bar: View {
		let volume: Volume
		let bottomAligned: Bool
		let showSpacer: Bool
		
		var body: some View {
			ZStack {
				Color.clear
			}
			.frame(maxWidth: 4)
			.overlay(
				GeometryReader { geo in
					VStack(spacing: 0) {
						Spacer(minLength: 0)
						
						HStack(spacing: 0) {
							Rectangle()
								.fill(.red)
								.frame(height: geo.height * pow(volume.unit, 8))
							
							if showSpacer {
								Rectangle()
									.fill(.clear)
									.frame(height: 1)
							}
						}

						if !bottomAligned { Spacer(minLength: 0) }
					}
				}
			)
		}
	}
}

#Preview {
	SoundLevelsView()
}
#endif
