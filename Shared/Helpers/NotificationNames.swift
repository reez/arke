import Foundation

extension Notification.Name {
    /// Posted when device is demoted from primary to secondary
    static let deviceDemotedFromPrimary = Notification.Name("deviceDemotedFromPrimary")
    
    /// Posted when device is promoted from secondary to primary
    static let devicePromotedToPrimary = Notification.Name("devicePromotedToPrimary")
    
    /// Posted when no primary device is detected
    static let showNoPrimaryDeviceBanner = Notification.Name("showNoPrimaryDeviceBanner")
}
