//
//  Microphone.History.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import CoreGraphics
import Combine
import Suite

extension Microphone {
	@MainActor public class History: ObservableObject {
		@Published var data: [DataPoint] = []
		
		public var currentLevel = 0.0
		public var currentNormalizedLevel = 0.0
		public var sampleCountLimit: Int? = 5000

		var maxVolume: Volume = .defaultMaxVolume
		var minVolume: Volume!
		var currentMinVolume: Volume {
			if let vol = minVolume { return vol }
			if maxVolume.db < 0 { return maxVolume }
			return .silence
		}
		
		var dbRange: Range<Double> { currentMinVolume.db..<maxVolume.db }
		var startedAt = Date()
		
		public var duration: TimeInterval { abs(startedAt.timeIntervalSinceNow) }
		
		public var mostRecent: Volume { data.last?.volume ?? .silence }
		
		public var instantNormalizedDB: Double {
			let minDB = currentMinVolume.db
			let delta = (maxVolume.db - minDB)
			
			return (mostRecent.db - minDB) / max(delta, 0.01)
		}
		
		public func average(over timeInterval: TimeInterval) -> Double? {
			var total: Double = 0
			let recent = data(inLast: timeInterval)
			guard recent.count > 0 else { return nil }
			
			for dataPoint in recent {
				total += dataPoint.db
			}
			
			return total / Double(recent.count)
		}
		
		func reset() {
			self.data = []
			startedAt = Date()
		}
		
		struct DataPoint {
			let offset: TimeInterval
			let volume: Volume
		}
		
		public func recent(_ count: Int) -> [Volume] {
			let data = data
			let length = min(data.count, count)
			let range = (data.count - length)..<data.count
			let volumes = Array(data[range]).map { $0.volume }
			
			return Array(repeating: Volume.silence, count: count - volumes.count) + volumes
		}
		
		public func data(inLast screenPoints: CGFloat) -> [Volume] {
				let data = data
			if data.isEmpty { return [] }
			let startIndex = Swift.max(0, data.count - Int(screenPoints))
			
			return Array(data[startIndex..<data.count]).map { $0.volume }
		}

		public func data(inLast seconds: TimeInterval) -> [Volume] {
			let duration = self.duration
			if duration > seconds {
                let offset = duration - seconds
                let data = self.data.reversed()
                if let index = data.firstIndex(where: { $0.offset < offset }) {
                    if index == data.startIndex { return [] }
                    return Array(data[data.startIndex..<index]).map { $0.volume }
                }
			}
			
			return data.map { $0.volume }
		}
		
		public struct LoggedAmbientSound: Codable {
			public let date: Date
			public let volume: Double
			
			init(_ date: Date, _ volume: Volume) {
				self.date = date
				self.volume = volume.db
			}
		}
		
		public func clear(from first: Date? = nil, through end: Date) {
			guard let start = first?.timeIntervalSince(startedAt) ?? data.first?.offset else { return }
			let end = end.timeIntervalSince(startedAt)
			
			data = data.filter { $0.offset < start || $0.offset > end }
		}
		
		public func data(from first: Date?, through end: Date) -> [LoggedAmbientSound] {
			guard let start = first?.timeIntervalSince(startedAt) ?? data.first?.offset else { return [] }
			let end = end.timeIntervalSince(startedAt)
			
			return data.filter { $0.offset >= start && $0.offset <= end }.map { LoggedAmbientSound(startedAt.addingTimeInterval($0.offset), $0.volume) }
		}
		
		func record(volume: Volume) {
			Task {
				await MainActor.run {
                    var newData = data
                    if let limit = sampleCountLimit, newData.count >= limit {
                        newData.removeFirst(newData.count - limit)
                    }
					let newDataPoint = DataPoint(offset: abs(self.startedAt.timeIntervalSinceNow), volume: volume)
					newData.append(newDataPoint)
                    self.data = newData
                    
					if volume > self.maxVolume { self.maxVolume = volume }
					if self.minVolume == nil || volume < self.minVolume { self.minVolume = volume }
					self.currentLevel = volume.db
					self.currentNormalizedLevel = self.instantNormalizedDB
					Microphone.Notifications.volumeChanged.notify()
				}
			}
		}
	}
}
