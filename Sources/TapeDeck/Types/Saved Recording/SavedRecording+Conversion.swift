//
//  SavedRecording+Conversion.swift
//  
//
//  Created by Ben Gottlieb on 9/7/23.
//

import AVFoundation

public extension SavedRecording {
	var data: Data? {
		get async {
			if isPackage {
				return fileURLs.compactMap { url in url.wavData }.reduce(.init(), +)
			} else {
				return url.wavData
			}
		}
	}
	
	var fileURLs: [URL] {
		if isPackage {
			return segmentInfo.map { $0.url(basedOn: url) }
		} else {
			return [url]
		}
	}
}

extension URL {
	var wavData: Data? {
		if pathExtension.lowercased() == "wav" {
			return try? Data(contentsOf: self)
		} else {
			let temp = URL.tempFile(named: lastPathComponent)
			try? FileManager.default.removeItem(at: temp)
			
			do {
				try AudioFileConverter.convert(m4a: self, toWAV: temp)
				return try? Data(contentsOf: temp)
			} catch {
				print("Failed to convert file \(lastPathComponent): \(error)")
				return nil
			}
		}
	}
}
