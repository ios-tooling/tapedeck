//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 2/11/25.
//

#if os(iOS)
import Foundation

extension URL {
	var detectedAudioFileType: Recorder.AudioFileType? {
		switch pathExtension.lowercased() {
		case "raw": .raw
		case "wav": .wav16k
		case "m4a": .m4a
		case "mp3": .mp3
		default: nil
		}
	}
}
#endif
