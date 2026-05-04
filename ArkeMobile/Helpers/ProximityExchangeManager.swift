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
    @Published private(set) var discoveredPeers: Set<String> = []
    @Published private(set) var isAdvertising: Bool = false
    @Published private(set) var isBrowsing: Bool = false
    
    // MARK: - Private Properties
    
    private let serviceType = "arkepayment"
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
        triggerSearchingHaptic()
    }
    
    /// Stop all exchange activities and clean up
    func stopExchange() {
        proximityTimer?.invalidate()
        proximityTimer = nil
        
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
        
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        
        niSession?.invalidate()
        niSession = nil
        niDiscoveryToken = nil
        
        session?.disconnect()
        session = nil
        
        connectedPeer = nil
        myBIP21URI = nil
        myAvatarData = nil
        hasExchangedInCurrentSession = false
        discoveredPeers.removeAll()
        
        state = .idle
        
        print("[ProximityExchange] Stopped exchange and cleaned up")
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
        isAdvertising = true
        print("[ProximityExchange] Started advertising as '\(myPeerID.displayName)' with service type '\(serviceType)'")
    }
    
    private func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        isBrowsing = true
        print("[ProximityExchange] Started browsing for peers with service type '\(serviceType)'")
    }
    
    private func startNearbyInteraction() {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            print("[ProximityExchange] NearbyInteraction not supported on this device")
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        niDiscoveryToken = niSession?.discoveryToken
        print("[ProximityExchange] Started NearbyInteraction session with token: \(niDiscoveryToken != nil)")
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
        triggerExchangingHaptic()
        
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
            triggerErrorHaptic()
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
            triggerErrorHaptic()
        }
    }
    
    // MARK: - Haptic Feedback
    
    /// Very light tap when searching starts
    private func triggerSearchingHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    /// Light-medium tap when peer is discovered
    private func triggerPeerDiscoveredHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let impact2 = UIImpactFeedbackGenerator(style: .medium)
            impact2.impactOccurred()
        }
    }
    
    /// Medium tap when connection is established
    private func triggerConnectionHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Medium-heavy tap when proximity is detected
    private func triggerProximityMetHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let impact2 = UIImpactFeedbackGenerator(style: .heavy)
            impact2.impactOccurred()
        }
    }
    
    /// Heavy tap when exchange starts
    private func triggerExchangingHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }
    
    /// Success pattern - three quick taps
    private func triggerSuccessHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            impact.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            impact.impactOccurred()
        }
    }
    
    /// Error notification
    private func triggerErrorHaptic() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
    }
}

// MARK: - MCSessionDelegate

extension ProximityExchangeManager: MCSessionDelegate {
    
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange newState: MCSessionState) {
        Task { @MainActor in
            switch newState {
            case .connected:
                print("[ProximityExchange] Session connected to peer: \(peerID.displayName)")
                connectedPeer = peerID
                state = .peerFound(peerName: peerID.displayName)
                triggerConnectionHaptic()
                
                // Share NI discovery token if available
                if let token = niDiscoveryToken {
                    print("[ProximityExchange] Sharing NI discovery token with peer")
                    shareNIDiscoveryToken(token, with: peerID)
                } else {
                    // NearbyInteraction not supported - exchange immediately
                    print("[ProximityExchange] NI not available, exchanging immediately after connection")
                    checkAndInitiateExchange()
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
            print("[ProximityExchange] Sent NI token to peer: \(peer.displayName)")
        } catch {
            print("[ProximityExchange] Failed to share NI token: \(error)")
        }
    }
    
    private func handleReceivedNIToken(_ token: NIDiscoveryToken, from peer: MCPeerID) {
        guard let niSession = niSession else {
            print("[ProximityExchange] Received NI token but niSession is nil")
            return
        }
        
        print("[ProximityExchange] Received NI token from peer: \(peer.displayName), starting NI session")
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession.run(config)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension ProximityExchangeManager: MCNearbyServiceAdvertiserDelegate {
    
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            print("[ProximityExchange] Advertiser received invitation from peer: \(peerID.displayName)")
            
            // Auto-accept invitations when in tilt-share mode
            if let session = session {
                print("[ProximityExchange] Accepting invitation from peer: \(peerID.displayName)")
                invitationHandler(true, session)
            }
        }
    }
    
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            print("[ProximityExchange] Advertiser failed to start: \(error.localizedDescription)")
            state = .error("Failed to start advertising: \(error.localizedDescription)")
            isAdvertising = false
            triggerErrorHaptic()
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension ProximityExchangeManager: MCNearbyServiceBrowserDelegate {
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            print("[ProximityExchange] Browser found peer: \(peerID.displayName)")
            discoveredPeers.insert(peerID.displayName)
            triggerPeerDiscoveredHaptic()
            
            // Auto-invite found peers
            if let session = session {
                print("[ProximityExchange] Inviting peer: \(peerID.displayName)")
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            print("[ProximityExchange] Browser lost peer: \(peerID.displayName)")
            discoveredPeers.remove(peerID.displayName)
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            print("[ProximityExchange] Browser failed to start: \(error.localizedDescription)")
            state = .error("Failed to start browsing: \(error.localizedDescription)")
            isBrowsing = false
            triggerErrorHaptic()
        }
    }
}

// MARK: - NISessionDelegate

extension ProximityExchangeManager: NISessionDelegate {
    
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        Task { @MainActor in
            guard let object = nearbyObjects.first else {
                print("[ProximityExchange] NI update with no objects")
                return
            }
            
            print("[ProximityExchange] NI update - distance: \(object.distance?.description ?? "nil"), direction: \(object.direction?.description ?? "nil")")
            
            // Check if peer is within proximity threshold
            if let distance = object.distance, distance <= proximityThreshold {
                print("[ProximityExchange] Peer within proximity threshold (\(distance)m <= \(proximityThreshold)m)")
                
                // Peer is close enough - check direction too if available
                let isProximityMet = checkProximityConditions(object)
                
                // Check if we're in peerFound state (any peer name)
                if case .peerFound = state, isProximityMet {
                    print("[ProximityExchange] Proximity conditions met, setting state to proximityMet")
                    state = .proximityMet
                    triggerProximityMetHaptic()
                    
                    // Debounce: wait a moment to ensure stable proximity before exchanging
                    proximityTimer?.invalidate()
                    proximityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        Task { @MainActor in
                            self.checkAndInitiateExchange()
                        }
                    }
                } else {
                    print("[ProximityExchange] Current state: \(state), isProximityMet: \(isProximityMet)")
                }
            }
        }
    }
    
    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            print("[ProximityExchange] NI removed objects, reason: \(reason)")
        }
    }
    
    nonisolated func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in
            print("[ProximityExchange] NI session suspended")
        }
    }
    
    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in
            print("[ProximityExchange] NI session resumed")
        }
    }
    
    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        Task { @MainActor in
            print("[ProximityExchange] NI session invalidated with error: \(error.localizedDescription)")
        }
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
