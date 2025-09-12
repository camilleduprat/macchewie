//
//  OverlayWindowManager.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import Foundation
import AppKit
import SwiftUI

// MARK: - Overlay Window Manager
@MainActor
class OverlayWindowManager: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var detectedElements: [UIElement] = []
    @Published var hoveredElement: UIElement?
    
    private var overlayWindow: NSWindow?
    private var overlayView: OverlayView?
    private var mouseTrackingArea: NSTrackingArea?
    
    private let mouseMonitorQueue = DispatchQueue(label: "com.macchewie.mouse", qos: .userInitiated)
    private var globalMouseMonitor: Any?
    
    func showOverlay() throws {
        guard overlayWindow == nil else { return }
        
        do {
            try createOverlayWindow()
            startMouseTracking()
            isVisible = true
            
            print("👁️ Overlay window shown")
        } catch {
            print("❌ Failed to show overlay: \(error)")
            throw error
        }
    }
    
    func hideOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        overlayView = nil
        stopMouseTracking()
        isVisible = false
        detectedElements = []
        hoveredElement = nil
        
        print("👁️ Overlay window hidden")
    }
    
    func updateHighlights(_ elements: [UIElement]) {
        detectedElements = elements
        overlayView?.updateElements(elements)
        
        // Find element under current mouse position
        updateHoveredElement()
    }
    
    private func createOverlayWindow() throws {
        // Get screen bounds
        guard let screen = NSScreen.main else {
            throw OverlayError.noScreen
        }
        let screenFrame = screen.frame
        
        // Create window
        overlayWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        guard let window = overlayWindow else {
            throw OverlayError.windowCreationFailed
        }
        
        // Configure window properties
        window.level = .floating // Above other windows
        window.ignoresMouseEvents = false // Allow mouse interaction
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create overlay view
        overlayView = OverlayView()
        overlayView?.onElementClicked = { element in
            self.handleElementClick(element)
        }
        
        guard let overlayView = overlayView else {
            throw OverlayError.viewCreationFailed
        }
        
        window.contentView = NSHostingView(rootView: overlayView)
        window.makeKeyAndOrderFront(nil)
    }
    
    private func startMouseTracking() {
        // Create global mouse monitor
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }
    
    private func stopMouseTracking() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        let mouseLocation = event.locationInWindow
        updateHoveredElement(at: mouseLocation)
    }
    
    private func updateHoveredElement(at location: CGPoint = NSEvent.mouseLocation) {
        // Convert mouse location to screen coordinates
        guard let screen = NSScreen.main else { return }
        let screenLocation = CGPoint(x: location.x, y: screen.frame.height - location.y)
        
        // Find element under mouse
        let elementUnderMouse = detectedElements.first { element in
            element.bounds.contains(screenLocation)
        }
        
        if hoveredElement?.id != elementUnderMouse?.id {
            hoveredElement = elementUnderMouse
            overlayView?.setHoveredElement(elementUnderMouse)
        }
    }
    
    private func handleElementClick(_ element: UIElement) {
        print("🖱️ Element clicked: \(element.description)")
        
        // Post notification that an element was clicked
        NotificationCenter.default.post(
            name: .elementClicked,
            object: nil,
            userInfo: ["element": element]
        )
    }
}

// MARK: - Overlay View
struct OverlayView: View {
    @State private var elements: [UIElement] = []
    @State private var hoveredElement: UIElement?
    
    var onElementClicked: ((UIElement) -> Void)?
    
    var body: some View {
        ZStack {
            // Transparent background
            Color.clear
                .ignoresSafeArea()
            
            // Draw detected elements
            ForEach(elements, id: \.id) { element in
                ElementHighlightView(
                    element: element,
                    isHovered: hoveredElement?.id == element.id,
                    onClick: { onElementClicked?(element) }
                )
            }
        }
        .allowsHitTesting(true)
    }
    
    func updateElements(_ newElements: [UIElement]) {
        elements = newElements
    }
    
    func setHoveredElement(_ element: UIElement?) {
        hoveredElement = element
    }
}

// MARK: - Element Highlight View
struct ElementHighlightView: View {
    let element: UIElement
    let isHovered: Bool
    let onClick: () -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isHovered ? element.type.color : element.type.color.opacity(0.3),
                lineWidth: isHovered ? 3 : 2
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? element.type.color.opacity(0.1) : Color.clear)
            )
            .frame(width: element.bounds.width, height: element.bounds.height)
            .position(
                x: element.bounds.midX,
                y: element.bounds.midY
            )
            .onTapGesture {
                onClick()
            }
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Overlay Errors
enum OverlayError: Error, LocalizedError {
    case noScreen
    case windowCreationFailed
    case viewCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noScreen:
            return "No screen available"
        case .windowCreationFailed:
            return "Failed to create overlay window"
        case .viewCreationFailed:
            return "Failed to create overlay view"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let elementClicked = Notification.Name("elementClicked")
}

// MARK: - Screen Coordinate Conversion
extension NSScreen {
    var frame: CGRect {
        return self.frame
    }
}
