//
//  MotionManager.swift
//  Arké
//
//  Created by Christoph on 3/4/26.
//

#if os(iOS)
import CoreMotion
#endif
import Foundation

/// Manages device motion detection for tilt-based interactions
@Observable
@MainActor
class MotionManager {
    // MARK: - Public Properties
    
    /// Whether the device is currently tilted forward past the threshold
    private(set) var isForwardTilted: Bool = false
    
    /// Current pitch angle in degrees (for debugging)
    private(set) var currentPitchDegrees: Double = 0
    
    // MARK: - Private Properties
    
    #if os(iOS)
    private let motionManager = CMMotionManager()
    #endif
    
    /// Threshold angles in radians
    private let showThreshold: Double = 25.0 * .pi / 180  // Show overlay at 25°
    private let hideThreshold: Double = 20.0 * .pi / 180  // Hide overlay at 20° (hysteresis)
    
    /// Debounce timer to prevent jittery updates
    private nonisolated(unsafe) var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.1
    
    /// Pending state change (used for debouncing)
    private var pendingTiltState: Bool?
    
    // MARK: - Lifecycle
    
    init() {
        // Configuration happens in startMonitoring()
    }
    
    deinit {
        #if os(iOS)
        // Clean up synchronously - can't use async/await in deinit
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        debounceTimer?.invalidate()
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring device motion for tilt detection
    func startMonitoring() {
        #if os(iOS)
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ [MotionManager] Device motion not available")
            return
        }
        
        guard !motionManager.isDeviceMotionActive else {
            print("⚠️ [MotionManager] Motion monitoring already active")
            return
        }
        
        // Configure update interval (60 Hz is smooth without excessive battery drain)
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        
        // Start updates on main queue
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [MotionManager] Error: \(error.localizedDescription)")
                return
            }
            
            guard let motion = motion else { return }
            
            // Process the motion update
            self.handleMotionUpdate(motion)
        }
        
        print("✅ [MotionManager] Started monitoring device motion")
        #else
        print("⚠️ [MotionManager] Motion monitoring not available on macOS")
        #endif
    }
    
    /// Stop monitoring device motion
    func stopMonitoring() {
        #if os(iOS)
        guard motionManager.isDeviceMotionActive else { return }
        
        motionManager.stopDeviceMotionUpdates()
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingTiltState = nil
        
        print("🛑 [MotionManager] Stopped monitoring device motion")
        #endif
    }
    
    // MARK: - Private Methods
    
    #if os(iOS)
    private func handleMotionUpdate(_ motion: CMDeviceMotion) {
        // Get pitch angle from device attitude
        // Pitch: rotation around x-axis (tilting forward/backward)
        // Positive pitch = top of device tilting away from user (normal position)
        // Negative pitch = top of device tilting toward ground (forward tilt)
        let pitch = motion.attitude.pitch
        
        // Convert to degrees for debugging
        currentPitchDegrees = pitch * 180.0 / .pi
        
        // Check if we've crossed a threshold (use absolute value since we care about forward tilt)
        let absPitch = abs(pitch)
        
        // Determine if we should show/hide based on hysteresis
        let shouldShow = absPitch > showThreshold && pitch < 0  // Forward tilt (negative pitch)
        let shouldHide = absPitch < hideThreshold || pitch > 0  // Back to normal or tilted backward
        
        // Apply state change with hysteresis
        if shouldShow && !isForwardTilted {
            // Transition to tilted state
            scheduleDebouncedStateChange(to: true)
        } else if shouldHide && isForwardTilted {
            // Transition to normal state
            scheduleDebouncedStateChange(to: false)
        }
    }
    
    private func scheduleDebouncedStateChange(to newState: Bool) {
        // If we already have a pending change to this state, do nothing
        if pendingTiltState == newState {
            return
        }
        
        // Cancel any existing timer
        debounceTimer?.invalidate()
        
        // Store the pending state
        pendingTiltState = newState
        
        // Schedule the state change after debounce interval
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Apply the state change
            if let pendingState = self.pendingTiltState {
                self.isForwardTilted = pendingState
                self.pendingTiltState = nil
                
                print("🎯 [MotionManager] Tilt state changed: \(pendingState ? "FORWARD" : "NORMAL") (pitch: \(String(format: "%.1f°", self.currentPitchDegrees)))")
            }
        }
    }
    #endif
}
