//
//  Item.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
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
