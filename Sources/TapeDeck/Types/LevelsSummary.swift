//
//  LevelsSummary.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import Accelerate
import Suite

public class LevelsSummary: Codable, CustomStringConvertible {
	public typealias DataPoint = Int16
	var startedAt: Date!
	var granularity: TimeInterval = 20
	public var history: [DataPoint] = []
	var currentBatch: [DataPoint] = []
	var currentOffset = 0
	var endedAt: Date?
	var duration: TimeInterval? {
		guard let start = startedAt, let end = endedAt else { return nil }
		return end.timeIntervalSince(start)
	}
	var timeFrameString: String? {
		guard let start = startedAt else { return nil }
		
		let end = endedAt ?? startedAt.advanced(by: granularity * TimeInterval(history.count))
		
		return "\(start.localTimeString(date: .short, time: .short)) - \(end.localTimeString(date: .none, time: .short))"
	}
	
	public var description: String {
		"# of samples: \(history.count)"
	}
	
	public var minLevel: DataPoint { history.min() ?? 0 }
	public var maxLevel: DataPoint { history.max() ?? 0 }

	public func date(of sampleIndex: Int) -> Date? {
		guard let date = self.startedAt else { return nil }
		
		return date.addingTimeInterval(TimeInterval(sampleIndex) * granularity)
	}
	
	public func date(percentageIn: Double) -> Date? {
		guard let date = self.startedAt, let duration = duration else { return nil }
		
		return date.addingTimeInterval(TimeInterval(percentageIn) * duration)
	}
	

	func add(samples: [DataPoint]) {
		if startedAt == nil { startedAt = Date() }
		let offset = Int(abs(startedAt.timeIntervalSinceNow) / granularity)
		if offset == currentOffset {
			currentBatch += samples
		} else {
			addCurrentLevels()
			currentOffset = offset
		}
	}
	
	func addCurrentLevels() {
		if currentBatch.isEmpty { return }
		let db = 20 * log10(Float(currentBatch.squaredAverage))

		if !db.isNaN, !db.isInfinite { history.append(DataPoint(db)) }
		currentBatch = []
	}
	
	public func save(to url: URL) throws {
		currentBatch = []
		
		if endedAt == nil { endedAt = Date() }
		
		try saveJSON(to: url)
	}
}

