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
				
				DispatchQueue.main.async(after: 1.0) {
					print("Recording Interrruption ended \(self.interruptCount)")
					self.interruptCount -= 1
					if self.interruptCount != 0 || !self.isPausedDueToInterruption { return }
					self.isPausedDueToInterruption = false
//					Task { try? await self.start() }
				}
				
			@unknown default:
				print("Recording Unknown interruption kind")
			}
		}
	}
}
#endif
