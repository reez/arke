//
//  StringExtensions.swift
//  ArkeUI
//
//  Created by Christoph on 4/28/26.
//

extension String {
    public func chunked(into size: Int) -> [String] {
        var result: [String] = []
        var index = 0
        
        while index < self.count {
            let start = self.index(self.startIndex, offsetBy: index)
            let remainingCount = self.count - index
            
            if remainingCount >= size {
                // Full chunk
                let end = self.index(start, offsetBy: size)
                result.append(String(self[start..<end]))
                index += size
            } else {
                // Last chunk - keep it as is, don't pad
                let end = self.index(start, offsetBy: remainingCount)
                result.append(String(self[start..<end]))
                break
            }
        }
        
        return result
    }
}
