//
//  ScreenCaptureService.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import Foundation
import CoreGraphics
import AppKit
import SwiftUI

// MARK: - Detected Design Element
struct DetectedDesignElement {
    let id: UUID = UUID()
    let boundingBox: CGRect
    let type: DesignElementType
    let confidence: Float
}

enum DesignElementType: String, Identifiable, CaseIterable {
    var id: String { self.rawValue }
    case button = "Button"
    case text = "Text"
    case textField = "Text Field"
    case image = "Image"
    case container = "Container"
    case card = "Card"
    case navigation = "Navigation"
    case list = "List"
    case table = "Table"
    case header = "Header"
    case footer = "Footer"
    case sidebar = "Sidebar"
    case modal = "Modal"
    case toolbar = "Toolbar"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .button:
            return .blue
        case .text, .textField:
            return .green
        case .image:
            return .orange
        case .container:
            return .purple
        case .card:
            return .red
        case .navigation:
            return .indigo
        case .list, .table:
            return .teal
        case .header, .footer:
            return .brown
        case .sidebar:
            return .cyan
        case .modal:
            return .pink
        case .toolbar:
            return .yellow
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Screen Capture Service
class ScreenCaptureService: ObservableObject {
    @Published var isScanning = false
    @Published var detectedElements: [DetectedDesignElement] = []
    @Published var currentScreenImage: NSImage?
    @Published var errorMessage: String?
    
    private let openAIService = OpenAIVisionService()
    
    init() {
        print("🔍 [DEBUG] ScreenCaptureService initialized with OpenAI")
    }
    
    func captureAndAnalyzeScreen() async {
        print("🔍 [DEBUG] Starting screen capture and OpenAI analysis")

        await MainActor.run {
            print("🔍 [DEBUG] Setting scanning state to true")
            isScanning = true
            errorMessage = nil
            detectedElements = []
        }

        // Capture screen
        print("🔍 [DEBUG] Attempting to capture screen")
        guard let screenImage = captureScreen() else {
            print("❌ [DEBUG] Failed to capture screen")
            await MainActor.run {
                errorMessage = "Failed to capture screen"
                isScanning = false
            }
            return
        }

        print("✅ [DEBUG] Screen captured successfully, size: \(screenImage.size)")

        await MainActor.run {
            currentScreenImage = screenImage
        }

        // Analyze with OpenAI
        print("🤖 [DEBUG] Starting OpenAI analysis")
        let aiElements = await openAIService.analyzeScreenForUIElements(screenImage)
        print("🤖 [DEBUG] OpenAI analysis complete, found \(aiElements.count) elements")

        // Convert OpenAI elements to our format
        let convertedElements = aiElements.compactMap { aiElement -> DetectedDesignElement? in
            let elementType = mapOpenAITypeToDesignType(aiElement.type)
            return DetectedDesignElement(
                boundingBox: aiElement.boundingBox,
                type: elementType,
                confidence: aiElement.confidence
            )
        }

        print("✅ [DEBUG] Converted \(convertedElements.count) elements")

        await MainActor.run {
            detectedElements = convertedElements
            isScanning = false
            if let error = openAIService.errorMessage {
                errorMessage = error
            }
            print("✅ [DEBUG] Screen capture and OpenAI analysis completed successfully")
        }
    }
    
    private func captureScreen() -> NSImage? {
        print("🔍 [DEBUG] Capturing screen using CGDisplayCreateImage")
        
        guard let mainDisplay = CGDisplayCreateImage(CGMainDisplayID()) else {
            print("❌ [DEBUG] Failed to create screen image")
            return nil
        }
        
        let imageSize = CGSize(width: mainDisplay.width, height: mainDisplay.height)
        print("✅ [DEBUG] Screen image created, size: \(imageSize)")
        
        return NSImage(cgImage: mainDisplay, size: imageSize)
    }
    
    func getImageCrop(for element: DetectedDesignElement) -> NSImage? {
        print("🔍 [DEBUG] Getting image crop for element: \(element.type.rawValue)")
        
        guard let screenImage = currentScreenImage else {
            print("❌ [DEBUG] No screen image available")
            return nil
        }
        
        let cropRect = element.boundingBox
        
        // Ensure crop rect is within image bounds
        let imageSize = screenImage.size
        let clampedRect = CGRect(
            x: max(0, min(cropRect.origin.x, imageSize.width - cropRect.width)),
            y: max(0, min(cropRect.origin.y, imageSize.height - cropRect.height)),
            width: min(cropRect.width, imageSize.width - max(0, cropRect.origin.x)),
            height: min(cropRect.height, imageSize.height - max(0, cropRect.origin.y))
        )
        
        print("🔍 [DEBUG] Cropping image with rect: \(clampedRect)")
        
        guard let cgImage = screenImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            print("❌ [DEBUG] Failed to crop image")
            return nil
        }
        
        let croppedImage = NSImage(cgImage: croppedCGImage, size: clampedRect.size)
        print("✅ [DEBUG] Image cropped successfully, size: \(croppedImage.size)")
        
        return croppedImage
    }
    
    private func mapOpenAITypeToDesignType(_ openAIType: String) -> DesignElementType {
        let lowercased = openAIType.lowercased()
        
        switch lowercased {
        case let type where type.contains("button"):
            return .button
        case let type where type.contains("text field") || type.contains("input"):
            return .textField
        case let type where type.contains("text"):
            return .text
        case let type where type.contains("image"):
            return .image
        case let type where type.contains("card"):
            return .card
        case let type where type.contains("navigation") || type.contains("nav"):
            return .navigation
        case let type where type.contains("list"):
            return .list
        case let type where type.contains("table"):
            return .table
        case let type where type.contains("header"):
            return .header
        case let type where type.contains("footer"):
            return .footer
        case let type where type.contains("sidebar"):
            return .sidebar
        case let type where type.contains("modal") || type.contains("dialog"):
            return .modal
        case let type where type.contains("toolbar"):
            return .toolbar
        case let type where type.contains("container"):
            return .container
        default:
            return .unknown
        }
    }
}