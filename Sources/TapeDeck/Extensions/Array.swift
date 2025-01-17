//
//  Array.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation

public extension Array where Element == Float {
	var average: Float {
		if count == 0 { return 0 }
		let sum = self.sum()
		return floor(sum / Float(count))
	}
	
	var squaredAverage: Float {
		let sum = map({ pow($0, 2) }).sum()
		return floor(sqrt(sum / Float(count)))
	}
	
	func downsampled(from start: Double, to end: Double) -> [Element] {
		var results: [Element] = []

		if end == start / 3 {
			for i in stride(from: 0, to: count - 2, by: 3) {
				results.append((self[i] + self[i + 1] + self[i + 2]) / 3)
			}
			return results
		}
		let step = end / start
		var sum = 0.0
		var lastIndex = -1
		
		for element in self {
			if Int(sum) != lastIndex {
				results.append(element)
				lastIndex = Int(sum)
			}
			sum += step
		}
		return results
	}
}

public extension Array where Element == Int16 {
	func downsampled(from start: Double, to end: Double) -> [Element] {
		var results: [Element] = []

		if false && end == start / 3 {
			for i in stride(from: 0, to: count - 2, by: 3) {
				let total = Int32(self[i]) + Int32(self[i + 1]) + Int32(self[i + 2])
				results.append(Int16(total / 3))
			}
			return results
		}
		let step = end / start
		var sum = 0.0
		var lastIndex = -1
		
		for element in self {
			if Int(sum) != lastIndex {
				results.append(element)
				lastIndex = Int(sum)
			}
			sum += step
		}
		return results
	}

}

extension Array where Element == Int16 {
	var average: Element {
		if count == 0 { return 0 }
		let sum: Int64 = self.reduce(0) { Int64($0) + Int64($1) }
		return Int16(sum / Int64(count))
	}
	
	var squaredAverage: Element {
		if count == 0 { return 0 }
		let sum: Int64 = self.reduce(0) { Int64($0) + Int64($1) * Int64($1) }
		return Int16(sqrt(Double(sum / Int64(count))))
	}
}
