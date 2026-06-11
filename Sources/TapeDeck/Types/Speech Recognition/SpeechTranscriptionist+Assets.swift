//
//  SpeechTranscriptionist+Assets.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/10/26.
//

#if os(iOS)
import Suite
import Speech

@available(iOS 26.0, *)
extension SpeechTranscriptionist {
	// Ensures the on-device model for `locale` is reserved and installed before analysis.
	// Without an installed model SpeechTranscriber yields nothing and the system logs a
	// localspeechrecognition 1101 error (silent transcription).
	func ensureModel(for transcriber: SpeechTranscriber, locale: Locale) async throws {
		let target = locale.identifier(.bcp47)

		let supported = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
		guard supported.contains(target) else {
			logg("Speech: locale \(target) not in supportedLocales")
			throw Recorder.RecorderError.unsupportedLanguage
		}

		await reserveLocale(locale)

		if await isInstalled(target) {
			logg("Speech: model for \(target) already installed")
			return
		}

		logg("Speech: model for \(target) not installed; requesting download")
		if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
			try await request.downloadAndInstall()
			logg("Speech: model download complete")
		} else {
			logg("Speech: no installation request returned (system reports nothing to install)")
		}

		if await !isInstalled(target) {
			logg("Speech: model for \(target) STILL not installed after download attempt")
		}
	}

	private func isInstalled(_ bcp47: String) async -> Bool {
		await SpeechTranscriber.installedLocales.contains { $0.identifier(.bcp47) == bcp47 }
	}

	// Reserves the locale so its on-device model survives storage reclamation.
	// Non-fatal: hitting the reserved-locale limit shouldn't abort transcription.
	func reserveLocale(_ locale: Locale) async {
		let reserved = await AssetInventory.reservedLocales
		if reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) { return }

		do {
			try await AssetInventory.reserve(locale: locale)
		} catch {
			logg(error: error, "Couldn't reserve locale \(locale.identifier) for on-device speech")
		}
	}
}
#endif
