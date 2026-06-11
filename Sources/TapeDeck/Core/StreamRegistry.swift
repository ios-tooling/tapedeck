//
//  StreamRegistry.swift
//  TapeDeck
//
//	 Fans one stream of values out to any number of AsyncStream consumers.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

final class StreamRegistry<Element: Sendable>: @unchecked Sendable {
	private let lock = NSLock()
	private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]

	func makeStream() -> AsyncStream<Element> {
		AsyncStream { continuation in
			let id = UUID()
			lock.withLock { continuations[id] = continuation }
			continuation.onTermination = { [weak self] _ in
				_ = self?.lock.withLock { self?.continuations.removeValue(forKey: id) }
			}
		}
	}

	func yield(_ element: Element) {
		let current = lock.withLock { Array(continuations.values) }
		current.forEach { $0.yield(element) }
	}

	func finishAll() {
		let current = lock.withLock {
			let values = Array(continuations.values)
			continuations.removeAll()
			return values
		}
		current.forEach { $0.finish() }
	}
}
