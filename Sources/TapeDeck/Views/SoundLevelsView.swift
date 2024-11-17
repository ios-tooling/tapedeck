//
//  SoundLevelsView.swift
//
//
//  Created by Ben Gottlieb on 9/7/23.
//

import SwiftUI

public struct SoundLevelsView: View {
	@ObservedObject var history = Microphone.instance.history
	let verticallyCentered: Bool
	let segmentWidth: CGFloat?
	let spacerWidth: CGFloat

	public init(verticallyCentered: Bool = true, segmentWidth: CGFloat? = 1, spacerWidth: CGFloat = 2) {
		self.verticallyCentered = verticallyCentered
		self.spacerWidth = spacerWidth
		self.segmentWidth = segmentWidth
	}
	
	public var body: some View {
		let bars = history.recent(100)
		
		BarLevelsView(levels: bars, verticallyCentered: verticallyCentered, segmentWidth: segmentWidth, spacerWidth: spacerWidth)
			.ignoresSafeArea()
	}
}

#Preview {
	SoundLevelsView()
}
