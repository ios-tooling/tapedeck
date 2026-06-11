//
//  AVAudioPCMBuffer+Copy.swift
//  TapeDeck
//
//	 Tap callbacks may reuse their buffers once the callback returns, so anything
//	 delivered asynchronously must be deep-copied first.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

extension AVAudioPCMBuffer {
	func deepCopy() -> AVAudioPCMBuffer? {
		guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
		copy.frameLength = frameLength

		let source = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
		let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)

		for (src, dst) in zip(source, destination) {
			guard let srcData = src.mData, let dstData = dst.mData else { continue }
			memcpy(dstData, srcData, Int(src.mDataByteSize))
		}
		return copy
	}
}
