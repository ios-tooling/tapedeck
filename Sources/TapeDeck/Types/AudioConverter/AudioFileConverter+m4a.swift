//
//  AudioFileConverter+m4a.swift
//  
//
//  Created by Ben Gottlieb on 9/8/23.
//

import Foundation
import AVFoundation

extension AudioFileConverter {
	@discardableResult static public func convert(wav url: URL, toM4A outputM4A: URL?, deleteSource: Bool = true) async throws -> URL {
		guard let exportSession = AVAssetExportSession(asset: AVAsset(url: url), presetName: AVAssetExportPresetAppleM4A) else {
			throw ConversionError.failedtoCreateExportSesssion
		}
		
		let output = outputM4A ?? url.deletingPathExtension().appendingPathExtension("m4a")
		exportSession.outputFileType = .m4a
		exportSession.outputURL = output
		
		try await exportSession.exportAsync()
		if deleteSource { try? FileManager.default.removeItem(at: url) }
		return output
	}
}

extension AVAssetExportSession: @unchecked @retroactive Sendable {
	func exportAsync() async throws {
		_ = try await withCheckedThrowingContinuation { continuation in
			self.exportAsynchronously {
				switch self.status {
				case .completed:
					continuation.resume()
				case .failed: fallthrough
				default:
					if let error = self.error {
						continuation.resume(throwing: error)
					} else {
						continuation.resume()
					}
				}
			}
		}
	}
}
