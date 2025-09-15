//
//  macchewieApp.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import SwiftUI

@main
struct macchewieApp: App {
    init() {
        print("🚀 [DEBUG] MacChewie app initializing")
    }
    
    var body: some Scene {
        print("🚀 [DEBUG] Creating app scene")
        
        let menuBarView = MenuBarView()
        print("🚀 [DEBUG] MenuBarView created")
        
        return MenuBarExtra("MacChewie", systemImage: "star.circle") {
            menuBarView
        }
        .menuBarExtraStyle(.window)
    }
}
