//
//  DesignSelectionView.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import SwiftUI
import AppKit

// MARK: - Cursor Extension
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct DesignSelectionView: View {
    let detectedElements: [DetectedDesignElement]
    let onElementSelected: (DetectedDesignElement) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Detected elements overlay
            ForEach(detectedElements, id: \.id) { element in
                ElementOverlay(
                    element: element,
                    onTap: { onElementSelected(element) }
                )
            }
            
            // Cancel button
            VStack {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(8)
                    .padding()
                }
                Spacer()
            }
            
            // Instructions
            VStack {
                Spacer()
                Text("Click on a design element to analyze it")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct ElementOverlay: View {
    let element: DetectedDesignElement
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        element.type.color,
                        lineWidth: isHovered ? 4 : 2
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(element.type.color.opacity(isHovered ? 0.3 : 0.1))
                    )
                    .scaleEffect(isHovered ? 1.02 : 1.0)
                    .shadow(
                        color: element.type.color.opacity(isHovered ? 0.5 : 0.2),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .frame(width: element.boundingBox.width, height: element.boundingBox.height)
            .position(
                x: element.boundingBox.midX,
                y: element.boundingBox.midY
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                onTap()
            }
            .cursor(isHovered ? .pointingHand : .arrow)
            .overlay(
                // Element type label
                Text(element.type.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, isHovered ? 12 : 8)
                    .padding(.vertical, isHovered ? 6 : 4)
                    .background(
                        RoundedRectangle(cornerRadius: isHovered ? 6 : 4)
                            .fill(element.type.color)
                            .shadow(
                                color: .black.opacity(isHovered ? 0.3 : 0.1),
                                radius: isHovered ? 4 : 2,
                                x: 0,
                                y: 1
                            )
                    )
                    .position(
                        x: element.boundingBox.minX + 50,
                        y: element.boundingBox.minY - 20
                    )
                    .opacity(isHovered ? 1 : 0.8)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            )
    }
}

// MARK: - Design Selection Window Manager
class DesignSelectionWindowManager: ObservableObject {
    private var selectionWindow: NSWindow?
    
    deinit {
        print("🎯 [DEBUG] DesignSelectionWindowManager deinitializing")
        closeSelectionWindow()
    }
    
    func showDesignSelection(
        elements: [DetectedDesignElement],
        onElementSelected: @escaping (DetectedDesignElement) -> Void,
        onCancel: @escaping () -> Void
    ) {
        print("🎯 [DEBUG] Showing design selection with \(elements.count) elements")
        
        // Close existing window if any
        closeSelectionWindow()
        
        // Create new window
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        print("🎯 [DEBUG] Creating window with frame: \(screenFrame)")
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        
        print("🎯 [DEBUG] Window created with level: \(window.level.rawValue)")
        
        // Create the SwiftUI view with weak self to avoid retain cycles
        let selectionView = DesignSelectionView(
            detectedElements: elements,
            onElementSelected: { [weak self] element in
                print("🎯 [DEBUG] Element selected: \(element.type.rawValue) at \(element.boundingBox)")
                
                // Call the callback first
                onElementSelected(element)
                
                // Close window on next run loop to avoid crash
                DispatchQueue.main.async {
                    self?.closeSelectionWindow()
                }
            },
            onCancel: { [weak self] in
                print("🎯 [DEBUG] Selection cancelled")
                
                // Call the callback first
                onCancel()
                
                // Close window on next run loop to avoid crash
                DispatchQueue.main.async {
                    self?.closeSelectionWindow()
                }
            }
        )
        
        print("🎯 [DEBUG] Creating NSHostingView with SwiftUI content")
        window.contentView = NSHostingView(rootView: selectionView)
        
        print("🎯 [DEBUG] Ordering window front (without making it key)")
        window.orderFront(nil)
        
        selectionWindow = window
        print("✅ [DEBUG] Design selection window shown successfully")
    }
    
    func closeSelectionWindow() {
        print("🎯 [DEBUG] Closing design selection window")
        
        // Properly clean up the window and its content
        if let window = selectionWindow {
            print("🎯 [DEBUG] Cleaning up window content")
            
            // Remove the content view first to break any remaining references
            if let hostingView = window.contentView as? NSHostingView<DesignSelectionView> {
                hostingView.rootView = DesignSelectionView(
                    detectedElements: [],
                    onElementSelected: { _ in },
                    onCancel: { }
                )
            }
            
            window.contentView = nil
            window.close()
            
            print("🎯 [DEBUG] Window closed successfully")
        }
        
        selectionWindow = nil
        print("✅ [DEBUG] Design selection window closed")
    }
}
