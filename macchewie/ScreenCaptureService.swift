//
//  ScreenCaptureService.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Screen Capture Service
@MainActor
class ScreenCaptureService: ObservableObject {
    @Published var hasPermission: Bool = false
    @Published var isCapturing: Bool = false
    
    private var lastScreenshot: NSImage?
    
    init() {
        checkPermissions()
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        // Check if we have screen recording permission
        hasPermission = CGPreflightScreenCaptureAccess()
    }
    
    func requestPermissions() {
        guard !hasPermission else { return }
        
        // This will show the system permission dialog
        let _ = CGRequestScreenCaptureAccess()
        
        // Check again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissions()
        }
    }
    
    // MARK: - Screen Capture
    
    func captureScreen() -> NSImage? {
        guard hasPermission else {
            print("⚠️ No screen recording permission")
            return nil
        }
        
        // Get the main display
        let mainDisplayID = CGMainDisplayID()
        
        // Create screen capture
        guard let cgImage = CGDisplayCreateImage(mainDisplayID) else {
            print("❌ Could not create screen capture")
            return nil
        }
        
        // Convert to NSImage
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        return image
    }
    
    func captureWindow(_ windowID: CGWindowID) -> NSImage? {
        guard hasPermission else {
            print("⚠️ No screen recording permission")
            return nil
        }
        
        guard let cgImage = CGWindowListCreateImage(
            CGRect.null,
            .optionIncludingWindow,
            windowID,
            .bestResolution
        ) else {
            print("❌ Could not capture window \(windowID)")
            return nil
        }
        
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        return image
    }
    
    // MARK: - Change Detection
    
    func hasSignificantChanges(from oldImage: NSImage?, to newImage: NSImage) -> Bool {
        guard let oldImage = oldImage else { return true } // First capture
        
        // Quick comparison using image hashes
        let oldHash = imageHash(oldImage)
        let newHash = imageHash(newImage)
        
        // Consider it changed if hash is different
        return oldHash != newHash
    }
    
    private func imageHash(_ image: NSImage) -> String {
        // Simple hash based on image size and a few sample pixels
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Sample a few pixels for quick comparison
        var hashComponents: [String] = ["\(width)x\(height)"]
        
        // Sample pixels at strategic locations (corners and center)
        let samplePoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: CGFloat(width - 1), y: 0),
            CGPoint(x: 0, y: CGFloat(height - 1)),
            CGPoint(x: CGFloat(width - 1), y: CGFloat(height - 1)),
            CGPoint(x: CGFloat(width / 2), y: CGFloat(height / 2))
        ]
        
        for point in samplePoints {
            if let color = getPixelColor(in: image, at: point) {
                hashComponents.append("\(color.red),\(color.green),\(color.blue)")
            }
        }
        
        return hashComponents.joined(separator: "|")
    }
    
    private func getPixelColor(in image: NSImage, at point: CGPoint) -> (red: Float, green: Float, blue: Float)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Clamp point to image bounds
        let x = max(0, min(Int(point.x), width - 1))
        let y = max(0, min(Int(point.y), height - 1))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: -x, y: -y, width: width, height: height))
        
        let red = Float(pixelData[0]) / 255.0
        let green = Float(pixelData[1]) / 255.0
        let blue = Float(pixelData[2]) / 255.0
        
        return (red: red, green: green, blue: blue)
    }
    
    // MARK: - Continuous Capture Support
    
    func updateLastScreenshot(_ image: NSImage) {
        lastScreenshot = image
    }
    
    func getLastScreenshot() -> NSImage? {
        return lastScreenshot
    }
}
