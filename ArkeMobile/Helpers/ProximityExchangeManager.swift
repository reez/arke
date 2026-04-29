//
//  ProximityExchangeManager.swift
//  Arké
//
//  Manages proximity-based payment info exchange using MultipeerConnectivity and NearbyInteraction
//

import Foundation
import MultipeerConnectivity
import NearbyInteraction
import Combine
import Network

/// Represents the current state of the proximity exchange session
enum ProximityExchangeState: Equatable {
    case idle
    case awaitingPermission
    case discovering
    case peerFound(peerName: String)
    case proximityMet
    case exchanging
    case complete(bip21URI: String, peerName: String)
    case error(String)
}

/// Manages peer-to-peer proximity exchange of payment information
@MainActor
class ProximityExchangeManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var state: ProximityExchangeState = .idle
    @Published var receivedPaymentInfo: ReceivedPaymentInfo?
    
    // MARK: - Private Properties
    
    private let serviceType = "arke-payment"
    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // NearbyInteraction (iPhone 11+)
    private var niSession: NISession?
    private var niDiscoveryToken: NIDiscoveryToken?
    private var connectedPeer: MCPeerID?
    
    // Exchange tracking
    private var hasExchangedInCurrentSession = false
    private var proximityTimer: Timer?
    private var myBIP21URI: String?
    private var myAvatarData: Data?
    
    // Distance threshold for proximity detection (in meters)
    private let proximityThreshold: Float = 1.5
    
    // MARK: - Initialization
    
    override init() {
        // Create a unique peer ID based on device name
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Show permission prompt
    func showPermissionPrompt(bip21URI: String, avatarData: Data? = nil) {
        guard state == .idle else { return }
        
        myBIP21URI = bip21URI
        myAvatarData = avatarData
        state = .awaitingPermission
    }
    
    /// Start advertising and browsing for peers with the given payment info
    func startExchange(bip21URI: String, avatarData: Data? = nil) {
        guard state == .awaitingPermission || state == .idle else { return }
        
        myBIP21URI = bip21URI
        myAvatarData = avatarData
        hasExchangedInCurrentSession = false
        receivedPaymentInfo = nil
        
        setupSession()
        startAdvertising()
        startBrowsing()
        startNearbyInteraction()
        
        state = .discovering
    }
    
    /// Stop all exchange activities and clean up
    func stopExchange() {
        proximityTimer?.invalidate()
        proximityTimer = nil
        
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        
        browser?.stopBrowsingForPeers()
        browser = nil
        
        niSession?.invalidate()
        niSession = nil
        niDiscoveryToken = nil
        
        session?.disconnect()
        session = nil
        
        connectedPeer = nil
        myBIP21URI = nil
        myAvatarData = nil
        hasExchangedInCurrentSession = false
        
        state = .idle
    }
    
    /// Clear received payment info (after user handles it)
    func clearReceivedPaymentInfo() {
        receivedPaymentInfo = nil
    }
    
    // MARK: - Private Setup Methods
    
    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
    }
    
    private func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }
    
    private func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    private func startNearbyInteraction() {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else { return }
        
        niSession = NISession()
        niSession?.delegate = self
        niDiscoveryToken = niSession?.discoveryToken
    }
    
    // MARK: - Exchange Logic
    
    private func checkAndInitiateExchange() {
        // Only exchange once per session and only if we haven't already
        guard !hasExchangedInCurrentSession,
              let peer = connectedPeer,
              let uri = myBIP21URI else { return }
        
        // Mark as exchanged immediately to prevent duplicate sends
        hasExchangedInCurrentSession = true
        state = .exchanging
        
        sendPaymentInfo(uri: uri, to: peer)
    }
    
    private func sendPaymentInfo(uri: String, to peer: MCPeerID) {
        guard let session = session else { return }
        
        let payload = PaymentInfoPayload(bip21URI: uri, avatarData: myAvatarData)
        
        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            state = .error("Failed to send payment info: \(error.localizedDescription)")
        }
    }
    
    private func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        do {
            let payload = try JSONDecoder().decode(PaymentInfoPayload.self, from: data)
            
            // Store received payment info
            receivedPaymentInfo = ReceivedPaymentInfo(
                bip21URI: payload.bip21URI,
                avatarData: payload.avatarData
            )
            
            state = .complete(bip21URI: payload.bip21URI, peerName: peer.displayName)
            
            // Trigger haptic feedback
            triggerSuccessHaptic()
            
        } catch {
            state = .error("Failed to decode payment info: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerSuccessHaptic() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    private func triggerDetectionHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - MCSessionDelegate

extension ProximityExchangeManager: MCSessionDelegate {
    
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange newState: MCSessionState) {
        Task { @MainActor in
            switch newState {
            case .connected:
                connectedPeer = peerID
                state = .peerFound(peerName: peerID.displayName)
                triggerDetectionHaptic()
                
                // Share NI discovery token if available
                if let token = niDiscoveryToken {
                    shareNIDiscoveryToken(token, with: peerID)
                }
                
            case .notConnected:
                if connectedPeer == peerID {
                    connectedPeer = nil
                    if state != .complete(bip21URI: "", peerName: "") {
                        state = .discovering
                    }
                }
                
            case .connecting:
                break
                
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            // Check if this is NI token data or payment info
            if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                handleReceivedNIToken(token, from: peerID)
            } else {
                handleReceivedData(data, from: peerID)
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
    
    // MARK: - NI Token Sharing
    
    private func shareNIDiscoveryToken(_ token: NIDiscoveryToken, with peer: MCPeerID) {
        guard let session = session else { return }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            print("Failed to share NI token: \(error)")
        }
    }
    
    private func handleReceivedNIToken(_ token: NIDiscoveryToken, from peer: MCPeerID) {
        guard let niSession = niSession else { return }
        
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession.run(config)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension ProximityExchangeManager: MCNearbyServiceAdvertiserDelegate {
    
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Auto-accept invitations when in tilt-share mode
            if let session = session {
                invitationHandler(true, session)
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension ProximityExchangeManager: MCNearbyServiceBrowserDelegate {
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            // Auto-invite found peers
            if let session = session {
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Peer lost - handled by session state changes
    }
}

// MARK: - NISessionDelegate

extension ProximityExchangeManager: NISessionDelegate {
    
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        Task { @MainActor in
            guard let object = nearbyObjects.first else { return }
            
            // Check if peer is within proximity threshold
            if let distance = object.distance, distance <= proximityThreshold {
                // Peer is close enough - check direction too if available
                let isProximityMet = checkProximityConditions(object)
                
                if isProximityMet && state == .peerFound(peerName: "") {
                    state = .proximityMet
                    
                    // Debounce: wait a moment to ensure stable proximity before exchanging
                    proximityTimer?.invalidate()
                    proximityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        Task { @MainActor in
                            self.checkAndInitiateExchange()
                        }
                    }
                }
            }
        }
    }
    
    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Object removed - proximity lost
    }
    
    nonisolated func sessionWasSuspended(_ session: NISession) {
        // Session suspended
    }
    
    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        // Session resumed
    }
    
    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        // Session invalidated
    }
    
    private func checkProximityConditions(_ object: NINearbyObject) -> Bool {
        // For now, just check distance
        // In the future, could add direction checks (azimuth/elevation) to ensure devices are facing each other
        guard let distance = object.distance else { return false }
        
        return distance <= proximityThreshold
    }
}

// MARK: - Supporting Types

struct PaymentInfoPayload: Codable {
    let bip21URI: String
    let avatarData: Data?
}

struct ReceivedPaymentInfo: Equatable {
    let bip21URI: String
    let avatarData: Data?
}
