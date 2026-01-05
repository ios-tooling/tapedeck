//
//  Recorder+Interruptions.swift
//
//
//  Created by Ben Gottlieb on 9/1/23.
//

#if os(iOS)
import Foundation
import AVFoundation

extension Recorder {
	func setupInterruptions() {
		AVAudioSession.interruptionNotification.publisher()
			.receive(on: RunLoop.main)
			.sink { note in
				self.handleInterruption(note: note)
			}.store(in: &cancelBag)
	}
	
	func handleInterruption(note: Notification) {
		if let type = note.interruptionType {
			switch type {
			case .began:
				print("Recording Interrruption began")
				isPausedDueToInterruption = true
				interruptCount += 1
				Task { try? await self.stop() }
				
			case .ended:
				if self.interruptCount == 0 { return }

				Task { @MainActor in
					try? await Task.sleep(nanoseconds: 1_000_000_000)
					print("Recording Interrruption ended \(self.interruptCount)")
					self.interruptCount -= 1
					if self.interruptCount != 0 || !self.isPausedDueToInterruption { return }
					self.isPausedDueToInterruption = false
					// NOTE: Auto-resume is intentionally disabled. Automatically restarting recording
					// after interruptions (like phone calls) could be unexpected UX and may have
					// privacy implications. Users should manually resume recording if desired.
					// TODO: Consider making this configurable via a property like `shouldAutoResumeAfterInterruption`
					// Task { try? await self.start() }
				}
				
			@unknown default:
				print("Recording Unknown interruption kind")
			}
		}
	}
}
#endif
