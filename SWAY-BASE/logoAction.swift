import Foundation
import UIKit
import StoreKit

public class Utils {
    static func openOrDownloadPlayPortal() {
        
        _ = SKStoreProductViewController()
        let playPortalURL = URL(string: "playportal://")!
        
        
        if UIApplication.shared.canOpenURL(playPortalURL) {
            UIApplication.shared.openURL(playPortalURL)
        }
        else {
            print("Cannot Open")
        }
    }
}
