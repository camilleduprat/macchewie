//
//  ScreenScanner.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import Foundation
import AppKit
import Combine

// MARK: - Screen Scanner
@MainActor
class ScreenScanner: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var hasPermission: Bool = false
    @Published var detectedElements: [UIElement] = []
    @Published var lastScanTime: Date?
    @Published var scanCount: Int = 0
    
    // Services
    private let screenCaptureService = ScreenCaptureService()
    let designDetectionService = DesignDetectionService()
    private let overlayWindowManager = OverlayWindowManager()
    
    // Scanning control
    private var scanTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance monitoring
    private var lastScanDuration: TimeInterval = 0
    private var averageScanDuration: TimeInterval = 0
    private var scanDurations: [TimeInterval] = []
    
    init() {
        setupBindings()
        checkInitialPermissions()
    }
    
    deinit {
        Task { @MainActor in
            stopScanning()
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind screen capture permission
        screenCaptureService.$hasPermission
            .assign(to: &$hasPermission)
        
        // Listen for element clicks
        NotificationCenter.default.publisher(for: .elementClicked)
            .sink { [weak self] notification in
                self?.handleElementClick(notification)
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialPermissions() {
        hasPermission = screenCaptureService.hasPermission
    }
    
    // MARK: - Public Interface
    
    func startScanning() {
        guard !isScanning else { return }
        
        // Check permissions first
        if !hasPermission {
            requestPermissions()
            return
        }
        
        print("🔍 Starting screen scanning...")
        
        do {
            isScanning = true
            scanCount = 0
            
            // Show overlay with error handling
            try overlayWindowManager.showOverlay()
            
            // Start periodic scanning
            startScanTimer()
            
            // Perform initial scan
            Task {
                await performScan()
            }
        } catch {
            print("❌ Failed to start scanning: \(error)")
            isScanning = false
            showError("Failed to start scanning: \(error.localizedDescription)")
        }
    }
    
    func stopScanning() {
        guard isScanning else { return }
        
        print("🔍 Stopping screen scanning...")
        isScanning = false
        
        // Stop timer
        scanTimer?.invalidate()
        scanTimer = nil
        
        // Hide overlay
        overlayWindowManager.hideOverlay()
        
        // Clear detected elements
        detectedElements = []
    }
    
    func requestPermissions() {
        screenCaptureService.requestPermissions()
        
        // Show permission dialog
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "MacChewie needs screen recording permission to analyze your screen designs. Please grant permission in System Preferences."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Screen Recording
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Scanning Logic
    
    private func startScanTimer() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performScan()
            }
        }
    }
    
    private func performScan() async {
        guard isScanning else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 1. Capture screen
            guard let screenshot = screenCaptureService.captureScreen() else {
                print("❌ Failed to capture screen")
                return
            }
            
            // 2. Check if screen has changed significantly
            if !screenCaptureService.hasSignificantChanges(
                from: screenCaptureService.getLastScreenshot(),
                to: screenshot
            ) {
                // Screen hasn't changed, skip detection
                return
            }
            
            // 3. Detect UI elements with error handling
            let elements = await designDetectionService.detectUIElements(in: screenshot)
            
            // 4. Update overlay with detected elements
            await MainActor.run {
                self.overlayWindowManager.updateHighlights(elements)
                
                // 5. Update state
                self.detectedElements = elements
                self.lastScanTime = Date()
                self.scanCount += 1
                
                // 6. Update last screenshot
                self.screenCaptureService.updateLastScreenshot(screenshot)
                
                // 7. Calculate performance metrics
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                self.updatePerformanceMetrics(duration)
                
                print("🔍 Scan completed: \(elements.count) elements detected in \(String(format: "%.2f", duration))s")
            }
            
        } catch {
            print("❌ Scan failed: \(error)")
            await MainActor.run {
                self.showError("Scan failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func updatePerformanceMetrics(_ duration: TimeInterval) {
        lastScanDuration = duration
        scanDurations.append(duration)
        
        // Keep only last 10 measurements
        if scanDurations.count > 10 {
            scanDurations.removeFirst()
        }
        
        // Calculate average
        averageScanDuration = scanDurations.reduce(0, +) / Double(scanDurations.count)
    }
    
    // MARK: - Element Interaction
    
    private func handleElementClick(_ notification: Notification) {
        guard let element = notification.userInfo?["element"] as? UIElement else { return }
        
        print("🖱️ Element clicked: \(element.description)")
        
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .elementSelectedForAnalysis,
            object: nil,
            userInfo: ["element": element]
        )
    }
    
    // MARK: - Performance Info
    
    func getPerformanceInfo() -> String {
        let elementsCount = detectedElements.count
        let lastScan = lastScanDuration
        let average = averageScanDuration
        
        return """
        Elements: \(elementsCount)
        Last scan: \(String(format: "%.2f", lastScan))s
        Average: \(String(format: "%.2f", average))s
        Total scans: \(scanCount)
        """
    }
    
    // MARK: - State Management
    
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func isReadyToScan() -> Bool {
        return hasPermission && !designDetectionService.isProcessing
    }
    
    private func showError(_ message: String) {
        print("🚨 ERROR: \(message)")
        
        // Post error notification
        NotificationCenter.default.post(
            name: .scannerError,
            object: nil,
            userInfo: ["error": message]
        )
    }
}

// MARK: - Additional Notifications
extension Notification.Name {
    static let elementSelectedForAnalysis = Notification.Name("elementSelectedForAnalysis")
    static let scannerError = Notification.Name("scannerError")
}
