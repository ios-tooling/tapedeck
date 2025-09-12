//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/7/25.
//

import Suite
import Speech

extension Transcriber {
	public func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
		guard await supported(locale: locale) else {
			throw TranscriberError.localeNotSupported
		}
		
		if await installed(locale: locale) {
			return
		} else {
			try await downloadIfNeeded(for: transcriber)
		}
	}
	
	func supported(locale: Locale) async -> Bool {
		let supported = await SpeechTranscriber.supportedLocales
		return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
	}
	
	func installed(locale: Locale) async -> Bool {
		let installed = await Set(SpeechTranscriber.installedLocales)
		return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
	}
	
	func downloadIfNeeded(for module: SpeechTranscriber) async throws {
		if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
			self.modelDownloadProgress = downloader.progress
			try await downloader.downloadAndInstall()
		}
	}
	
	func deallocate() async {
		#if os(iOS)
			let allocated = await AssetInventory.allocatedLocales
				for locale in allocated {
				await AssetInventory.deallocate(locale: locale)
			}
		#endif
	}
}

