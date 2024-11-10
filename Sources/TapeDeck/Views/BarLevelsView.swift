//
//  SwiftUIView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/25/24.
//

import SwiftUI

public struct BarLevelsView: View {
	@State var levels: [Volume]?
	let url: URL?
	var verticallyCentered = true
	var segmentWidth: CGFloat?
	var spacerWidth = 0.0
	
	public init(levels: [Volume], verticallyCentered: Bool = true, segmentWidth: CGFloat? = 1, spacerWidth: Double = 2) {
		_levels = .init(initialValue: levels)
		url = nil
		self.verticallyCentered = verticallyCentered
		self.segmentWidth = segmentWidth
		self.spacerWidth = spacerWidth
	}
	
	public init(url: URL, verticallyCentered: Bool = true, segmentWidth: CGFloat? = 1, spacerWidth: Double = 2) {
		self.url = url
		self.verticallyCentered = verticallyCentered
		self.segmentWidth = segmentWidth
		self.spacerWidth = spacerWidth
	}
	
	public var body: some View {
		HStack(spacing: 0) {
			if let levels {
				ForEach(levels.indices, id: \.self) { idx in
					Bar(volume: levels[idx], verticallyCentered: verticallyCentered, segmentWidth: segmentWidth, spacerWidth: spacerWidth)
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
