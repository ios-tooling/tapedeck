//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/28/25.
//

import Foundation

public protocol Recordable: Observable {
	func record() async throws
	func pause()
	func resume() throws
	func stop()
}
