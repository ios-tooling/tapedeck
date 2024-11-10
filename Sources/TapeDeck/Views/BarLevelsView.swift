//
//  SwiftUIView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/25/24.
//

import SwiftUI

public struct BarLevelsView: View {
	let levels: [Volume]
	var verticallyCentered = true
	var segmentWidth: CGFloat?
	var spacerWidth = 0.0
	
	public init(levels: [Volume], verticallyCentered: Bool = true, segmentWidth: CGFloat? = nil, spacerWidth: Double = 0.0) {
		self.levels = levels
		self.verticallyCentered = verticallyCentered
		self.segmentWidth = segmentWidth
		self.spacerWidth = spacerWidth
	}
	
	public var body: some View {
		HStack(spacing: 0) {
			ForEach(levels.indices, id: \.self) { idx in
				Bar(volume: levels[idx], verticallyCentered: verticallyCentered, segmentWidth: segmentWidth, spacerWidth: spacerWidth)
			}
		}
		.ignoresSafeArea()
	}
	
	struct Bar: View {
		let volume: Volume
		let verticallyCentered: Bool
		let segmentWidth: CGFloat?
		let spacerWidth: CGFloat

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
							RoundedRectangle(cornerRadius: (segmentWidth ?? 0) / 2)
								.fill(.red)
								.frame(width: segmentWidth, height: geo.height * pow(volume.unit, 8))
							
							if spacerWidth > 0 {
								Rectangle()
									.fill(.clear)
									.frame(width: spacerWidth, height: 1)
							}
						}
						
						if verticallyCentered { Spacer(minLength: 0) }
					}
				}
			)
		}
	}
}

#Preview {
	BarLevelsView(levels: [])
}
