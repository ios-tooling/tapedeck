//
//  SwiftUIView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/25/24.
//

import SwiftUI

public struct BarLevelsView: View {
	@State var levels: [Volume]?
	let preloadedLevels: [Volume]?
	let url: URL?
	var verticallyCentered = true
	var segmentWidth: CGFloat?
	var spacerWidth = 0.0
	var barColor = Color.red
	
	public init(levels: [Volume], verticallyCentered: Bool = true, segmentWidth: CGFloat? = 1, spacerWidth: Double = 2, barColor: Color = .red) {
		preloadedLevels = levels
		url = nil
		
		self.barColor = barColor
		self.verticallyCentered = verticallyCentered
		self.segmentWidth = segmentWidth
		self.spacerWidth = spacerWidth
	}
	
	public init(url: URL, verticallyCentered: Bool = true, segmentWidth: CGFloat? = 1, spacerWidth: Double = 2, barColor: Color = .red) {
		preloadedLevels = nil
		self.barColor = barColor
		self.url = url
		self.verticallyCentered = verticallyCentered
		self.segmentWidth = segmentWidth
		self.spacerWidth = spacerWidth
	}
	
	public var body: some View {
		HStack(spacing: 0) {
			if let levels = levels ?? preloadedLevels {
				ForEach(levels.indices, id: \.self) { idx in
					Bar(volume: levels[idx], verticallyCentered: verticallyCentered, segmentWidth: segmentWidth, spacerWidth: spacerWidth, barColor: barColor)
				}
			}
		}
		.ignoresSafeArea()
		.task {
			if let url {
				do {
					levels = try await url.extractVolumes(count: 100)
				} catch {
					print("Failed to extract volumes from \(url.path): \(error)")
				}
			}
		}
	}
	
	struct Bar: View {
		let volume: Volume
		let verticallyCentered: Bool
		let segmentWidth: CGFloat?
		let spacerWidth: CGFloat
		let barColor: Color

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
								.fill(barColor)
								.frame(width: segmentWidth, height: geo.height * min(pow(volume.unit, 8), 1))
							
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
