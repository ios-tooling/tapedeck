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
				var result = Data()
				
				for url in fileURLs {
					if let chunk = await url.wavData { result += chunk }
				}
				return result
			} else {
				return await url.wavData
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
		get async {
			if pathExtension.lowercased() == "wav" {
				return try? Data(contentsOf: self)
			} else {
				let temp = URL.tempFile(named: lastPathComponent)
				try? FileManager.default.removeItem(at: temp)
				
				do {
					try await AudioFileConverter.convert(m4a: self, toWAV: temp)
					return try? Data(contentsOf: temp)
				} catch {
					print("Failed to convert file \(lastPathComponent): \(error)")
					return nil
				}
			}
		}
	}
}
