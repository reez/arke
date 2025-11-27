//
//  Item.swift
//  Arké mobile
//
//  Created by Christoph on 11/27/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
