//
//  DesignDetectionService.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import Foundation
import AppKit
import SwiftUI
import Vision
import CoreImage

// MARK: - UI Element Models
struct UIElement {
    let id: UUID = UUID()
    let bounds: CGRect
    let type: UIElementType
    let confidence: Float
    let text: String?
    let description: String
}

enum UIElementType: String, CaseIterable {
    case button = "Button"
    case textField = "TextField"
    case label = "Label"
    case image = "Image"
    case card = "Card"
    case list = "List"
    case navigation = "Navigation"
    case form = "Form"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .button:
            return Color.blue
        case .textField:
            return Color.green
        case .label:
            return Color.purple
        case .image:
            return Color.orange
        case .card:
            return Color.teal
        case .list:
            return Color.yellow
        case .navigation:
            return Color.red
        case .form:
            return Color.brown
        case .unknown:
            return Color.gray
        }
    }
}

// MARK: - Design Detection Service
@MainActor
class DesignDetectionService: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var lastProcessingTime: TimeInterval = 0
    
    private let visionQueue = DispatchQueue(label: "com.macchewie.vision", qos: .userInitiated)
    
    func detectUIElements(in image: NSImage) async -> [UIElement] {
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isProcessing = false
            lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
        }
        
        return await withCheckedContinuation { continuation in
            visionQueue.async {
                let elements = self.performDetection(on: image)
                DispatchQueue.main.async {
                    continuation.resume(returning: elements)
                }
            }
        }
    }
    
    private func performDetection(on image: NSImage) -> [UIElement] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Could not get CGImage from NSImage")
            return []
        }
        
        var detectedElements: [UIElement] = []
        
        // Create request handler with error handling
        guard let requestHandler = try? VNImageRequestHandler(cgImage: cgImage, options: [:]) else {
            print("❌ Could not create VNImageRequestHandler")
            return []
        }
        
        // 1. Text Detection
        let textElements = detectText(in: requestHandler, imageSize: image.size)
        detectedElements.append(contentsOf: textElements)
        
        // 2. Rectangle Detection (for buttons, cards, forms)
        let rectangleElements = detectRectangles(in: requestHandler, imageSize: image.size)
        detectedElements.append(contentsOf: rectangleElements)
        
        // 3. Face Detection (for profile images, avatars)
        let faceElements = detectFaces(in: requestHandler, imageSize: image.size)
        detectedElements.append(contentsOf: faceElements)
        
        // 4. Combine and filter overlapping elements
        let filteredElements = filterOverlappingElements(detectedElements)
        
        print("🔍 Detected \(filteredElements.count) UI elements")
        return filteredElements
    }
    
    // MARK: - Text Detection
    
    private func detectText(in requestHandler: VNImageRequestHandler, imageSize: NSSize) -> [UIElement] {
        var elements: [UIElement] = []
        
        let textRequest = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                let bounds = observation.boundingBox
                let screenBounds = VNImageRectForNormalizedRect(bounds, Int(imageSize.width), Int(imageSize.height))
                
                let element = UIElement(
                    bounds: screenBounds,
                    type: self.classifyTextElement(topCandidate.string),
                    confidence: observation.confidence,
                    text: topCandidate.string,
                    description: "Text: \(topCandidate.string)"
                )
                
                elements.append(element)
            }
        }
        
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([textRequest])
        } catch {
            print("❌ Text detection failed: \(error)")
        }
        
        return elements
    }
    
    private func classifyTextElement(_ text: String) -> UIElementType {
        let lowercased = text.lowercased()
        
        // Button indicators
        if lowercased.contains("button") || lowercased.contains("click") || 
           lowercased.contains("submit") || lowercased.contains("save") ||
           lowercased.contains("cancel") || lowercased.contains("ok") {
            return .button
        }
        
        // Navigation indicators
        if lowercased.contains("menu") || lowercased.contains("nav") ||
           lowercased.contains("home") || lowercased.contains("back") {
            return .navigation
        }
        
        // Form indicators
        if lowercased.contains("email") || lowercased.contains("password") ||
           lowercased.contains("name") || lowercased.contains("phone") ||
           lowercased.contains("@") {
            return .form
        }
        
        // Default to label for other text
        return .label
    }
    
    // MARK: - Rectangle Detection
    
    private func detectRectangles(in requestHandler: VNImageRequestHandler, imageSize: NSSize) -> [UIElement] {
        var elements: [UIElement] = []
        
        let rectangleRequest = VNDetectRectanglesRequest { request, error in
            guard let observations = request.results as? [VNRectangleObservation] else { return }
            
            for observation in observations {
                let bounds = observation.boundingBox
                let screenBounds = VNImageRectForNormalizedRect(bounds, Int(imageSize.width), Int(imageSize.height))
                
                let element = UIElement(
                    bounds: screenBounds,
                    type: self.classifyRectangleElement(bounds: bounds, imageSize: imageSize),
                    confidence: observation.confidence,
                    text: nil,
                    description: "Rectangle: \(observation.confidence)"
                )
                
                elements.append(element)
            }
        }
        
        rectangleRequest.maximumObservations = 20
        rectangleRequest.minimumAspectRatio = 0.2
        rectangleRequest.maximumAspectRatio = 5.0
        rectangleRequest.minimumSize = 0.01
        
        do {
            try requestHandler.perform([rectangleRequest])
        } catch {
            print("❌ Rectangle detection failed: \(error)")
        }
        
        return elements
    }
    
    private func classifyRectangleElement(bounds: CGRect, imageSize: NSSize) -> UIElementType {
        let width = bounds.width
        let height = bounds.height
        let aspectRatio = width / height
        
        // Small rectangles might be buttons
        if bounds.width < 0.1 && bounds.height < 0.05 {
            return .button
        }
        
        // Wide rectangles might be text fields or forms
        if aspectRatio > 3.0 && height < 0.1 {
            return .textField
        }
        
        // Square-ish rectangles might be cards or images
        if aspectRatio > 0.8 && aspectRatio < 1.2 && bounds.width > 0.2 {
            return .card
        }
        
        // Tall rectangles might be lists or navigation
        if aspectRatio < 0.5 && height > 0.3 {
            return .list
        }
        
        return .unknown
    }
    
    // MARK: - Face Detection
    
    private func detectFaces(in requestHandler: VNImageRequestHandler, imageSize: NSSize) -> [UIElement] {
        var elements: [UIElement] = []
        
        let faceRequest = VNDetectFaceRectanglesRequest { request, error in
            guard let observations = request.results as? [VNFaceObservation] else { return }
            
            for observation in observations {
                let bounds = observation.boundingBox
                let screenBounds = VNImageRectForNormalizedRect(bounds, Int(imageSize.width), Int(imageSize.height))
                
                let element = UIElement(
                    bounds: screenBounds,
                    type: .image,
                    confidence: observation.confidence,
                    text: nil,
                    description: "Face/Avatar"
                )
                
                elements.append(element)
            }
        }
        
        do {
            try requestHandler.perform([faceRequest])
        } catch {
            print("❌ Face detection failed: \(error)")
        }
        
        return elements
    }
    
    // MARK: - Element Filtering
    
    private func filterOverlappingElements(_ elements: [UIElement]) -> [UIElement] {
        var filtered: [UIElement] = []
        
        for element in elements.sorted(by: { $0.confidence > $1.confidence }) {
            // Check if this element overlaps significantly with any already added element
            let hasSignificantOverlap = filtered.contains { existingElement in
                let intersection = element.bounds.intersection(existingElement.bounds)
                let intersectionArea = intersection.width * intersection.height
                let elementArea = element.bounds.width * element.bounds.height
                let existingArea = existingElement.bounds.width * existingElement.bounds.height
                
                // Consider it overlapping if intersection is more than 50% of either element
                return intersectionArea > (elementArea * 0.5) || intersectionArea > (existingArea * 0.5)
            }
            
            if !hasSignificantOverlap {
                filtered.append(element)
            }
        }
        
        return filtered
    }
}

// MARK: - Helper Functions

extension CGRect {
    func convertedToScreenCoordinates(imageSize: NSSize) -> CGRect {
        // Convert from Vision's coordinate system (0,0 at bottom-left) to screen coordinates (0,0 at top-left)
        let screenY = imageSize.height - self.origin.y - self.height
        return CGRect(x: self.origin.x, y: screenY, width: self.width, height: self.height)
    }
}
