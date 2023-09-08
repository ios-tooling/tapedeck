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
				let datas = fileURLs.compactMap { url in
					if url.pathExtension.lowercased() == "wav" {
						return try? Data(contentsOf: url)
					} else {
						let temp = URL.tempFile(named: url.lastPathComponent)
						try? FileManager.default.removeItem(at: temp)
						
						do {
							try AudioFileConverter.convert(m4a: url, toWAV: temp)
							return try? Data(contentsOf: temp)
						} catch {
							print("Failed to convert file: \(error)")
							return nil
						}
					}
				}
				
				return datas.reduce(.init(), +)
			}
			guard let url = fileURLs.first else { return nil }
			
			if url.pathExtension.lowercased() != "wav" {
				let temp = URL.tempFile(named: url.lastPathComponent)
				try? FileManager.default.removeItem(at: temp)
				
				do {
					try AudioFileConverter.convert(m4a: url, toWAV: temp)
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
