//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/8/23.
//

#if os(iOS)
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
		
		await exportSession.export()
		if deleteSource { try? FileManager.default.removeItem(at: url) }
		return output
	}

}
#endif
