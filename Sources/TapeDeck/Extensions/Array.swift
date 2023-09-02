//
//  Array.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation

extension Array where Element == Float {
	var average: Float {
		if count == 0 { return 0 }
		let sum = self.sum()
		return floor(sum / Float(count))
	}
	
	var squaredAverage: Float {
		let sum = map({ pow($0, 2) }).sum()
		return floor(sqrt(sum / Float(count)))
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
