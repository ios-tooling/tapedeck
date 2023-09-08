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
			guard let url = fileURLs.first else { return nil }
			
			if url.pathExtension.lowercased() != "wav" {
				let temp = URL.tempFile(named: url.lastPathComponent)
				let converter = AudioFileConverter(source: url, to: .wav, at: temp, progress: nil)
				
				do {
					try await converter.convert()
					return try? Data(contentsOf: temp)
				} catch {
					print("Failed to convert file: \(error)")
					return nil
				}
			}
			
			return try? Data(contentsOf: url)
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
