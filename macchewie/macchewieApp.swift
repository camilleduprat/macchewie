//
//  macchewieApp.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import SwiftUI

@main
struct macchewieApp: App {
    var body: some Scene {
        MenuBarExtra("MacChewie", systemImage: "gear") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
