//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/6/23.
//

import Foundation
import AVFoundation

public extension URL {
	var audioDuration: TimeInterval? {
		let asset = AVURLAsset(url: self)
		
		guard let reader = try? AVAssetReader(asset: asset) else { return nil }
		return reader.asset.duration.seconds
	}
}
