//
//  SegmentedWriter.swift
//  TapeDeck
//
//	 Writes a recording as timed chunks inside a package folder, rotating files
//	 every `chunkDuration` seconds. With a ringDuration, old chunks are pruned so
//	 only the trailing window survives. Confined to RecordingSession's actor context.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

final class SegmentedWriter {
	let package: RecordingPackage
	let format: AudioFormat
	let chunkDuration: TimeInterval
	let ringDuration: TimeInterval?

	private var inputFormat: AVAudioFormat
	private var current: AudioFileWriter?
	private var currentStart: TimeInterval = 0
	private var chunkIndex = 0
	private var manifest: RecordingPackage.Manifest
	private var completedDuration: TimeInterval = 0

	var duration: TimeInterval { completedDuration + (current?.duration ?? 0) }

	init(package: RecordingPackage, format: AudioFormat, chunkDuration: TimeInterval, ringDuration: TimeInterval?, input: AVAudioFormat) throws {
		self.package = package
		self.format = format
		self.chunkDuration = chunkDuration
		self.ringDuration = ringDuration
		inputFormat = input
		manifest = RecordingPackage.Manifest(startedAt: Date(), format: format, chunks: [], levels: [])
		try package.save(manifest: manifest)
	}

	func updateInputFormat(_ input: AVAudioFormat) {
		inputFormat = input
		current?.updateInputFormat(input)
	}

	func write(_ buffer: AVAudioPCMBuffer) throws {
		if current == nil { try startChunk() }
		try current?.write(buffer)
		if let current, current.duration >= chunkDuration { try rotate() }
	}

	func recordLevel(_ level: AudioLevel) {
		manifest.levels.append(.init(offset: duration, level: level))
	}

	func finish() throws -> RecordingPackage {
		try closeChunk()
		try package.save(manifest: manifest)
		return package
	}

	private func startChunk() throws {
		currentStart = completedDuration
		let filename = "\(chunkIndex). \(Int(currentStart))-\(Int(chunkDuration)).\(format.fileExtension)"
		current = try AudioFileWriter(url: package.url.appendingPathComponent(filename), format: format, input: inputFormat)
	}

	private func rotate() throws {
		try closeChunk()
		prune()
		try package.save(manifest: manifest)
	}

	private func closeChunk() throws {
		guard let current else { return }

		_ = try current.finish()
		manifest.chunks.append(.init(filename: current.url.lastPathComponent, start: currentStart, duration: current.duration))
		completedDuration += current.duration
		chunkIndex += 1
		self.current = nil
	}

	private func prune() {
		guard let ringDuration else { return }
		let cutoff = completedDuration - ringDuration

		while let oldest = manifest.chunks.first, oldest.start + oldest.duration <= cutoff {
			try? FileManager.default.removeItem(at: package.url.appendingPathComponent(oldest.filename))
			manifest.chunks.removeFirst()
		}
		manifest.levels.removeAll { $0.offset <= cutoff }
	}
}
