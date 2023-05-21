//
//  VPNUtils.swift
//  openvpn_flutter
//
//  Created by 최성민 on 2023/05/03.
//

import Foundation
import NetworkExtension
import os.log

@available(iOS 9.0, *)
class VPNUtils {
    private var providerManager: NETunnelProviderManager?
    private var providerBundleIdentifier : String?
    private var localizedDescription : String?
    private var groupIdentifier : String?
    
    func onVpnStatusChangedString(notification : NEVPNStatus?) -> String?{
        if notification == nil {
            return "disconnected"
        }
        switch notification! {
        case NEVPNStatus.connected:
            return "connected";
        case NEVPNStatus.connecting:
            return "connecting";
        case NEVPNStatus.disconnected:
            return "disconnected";
        case NEVPNStatus.disconnecting:
            return "disconnecting";
        case NEVPNStatus.invalid:
            return "invalid";
        case NEVPNStatus.reasserting:
            return "reasserting";
        default:
            return "";
        }
    }
    
    func currentStatus() -> String? {
        return onVpnStatusChangedString(notification: self.providerManager?.connection.status)
    }
    
    func currentTraffic() -> String? {
        return UserDefaults.init(suiteName: SwiftOpenVPNFlutterPlugin.utils.groupIdentifier)?.string(forKey: "connectionUpdate")
    }
    
    func initialize(arguments: [String: Any], closure: @escaping (Any?) -> Void) {
        guard let providerBundleIdentifier = arguments["providerBundleIdentifier"] as? String else {
            closure("providerBundleIdentifier content empty or null")
            return
        }
        
        guard let localizedDescription = arguments["localizedDescription"] as? String else {
            closure("localizedDescription content empty or null")
            return
        }
        
        
        guard let groupIdentifier = arguments["groupIdentifier"] as? String else {
            closure("groupIdentifier content empty or null")
            return
        }
        
        self.groupIdentifier = groupIdentifier
        self.localizedDescription = localizedDescription
        self.providerBundleIdentifier = providerBundleIdentifier
        
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                closure("\(error)")
            } else {
                self.providerManager = managers?.first ?? NETunnelProviderManager()
                closure(nil)
            }
        }
    }
    
    
    func startVPNTunnel(arguments: [String: Any] ,clouser:@escaping (Any?) -> Void) {
        guard let configData = arguments["config"] as? String
        else {
            clouser("configData is empty or null")
            return
        }
        
        
        guard
              let username = arguments["username"] as? String
        else {
            clouser("username is empty or null")
            return
        }
        
        
        guard
              let password = arguments["password"] as? String
        else {
            clouser("password is empty or null")
            return
        }
        guard let groupIdentifier = self.groupIdentifier
        else {
            clouser("groupIdentifier is empty or null")
            return
        }
        
        guard let localizedDescription = self.localizedDescription
        else {
            clouser("localizedDescription is empty or null")
            return
        }
        
        guard let providerManager = self.providerManager
        else {
            clouser("providerManager is empty or null")
            return
        }
        
        providerManager.loadFromPreferences { error in
            if error == nil {
                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.serverAddress = ""
                tunnelProtocol.providerBundleIdentifier = self.providerBundleIdentifier
                tunnelProtocol.providerConfiguration = [
                    "config": configData.data(using: .utf8)!,
                    "groupIdentifier": groupIdentifier.data(using: .utf8)!,
                    "username" : username.data(using: .utf8)!,
                    "password" : password.data(using: .utf8)!,
                ]
                tunnelProtocol.disconnectOnSleep = false
                providerManager.protocolConfiguration = tunnelProtocol
                providerManager.localizedDescription = self.localizedDescription
                providerManager.isEnabled = true
                providerManager.saveToPreferences(completionHandler: { (error) in
                    if error == nil  {
                        providerManager.loadFromPreferences(completionHandler: { (error) in
                            if error != nil {
                                clouser(error);
                                return;
                            }
                            do {
                                let options: [String : NSObject] = [
                                    "username": username as NSString,
                                    "password": password as NSString,
                                ]
                                try self.providerManager?.connection.startVPNTunnel(options: options)
                                clouser(nil);
                            } catch let error {
                                self.stopVPNTunnel()
                                print("Error info: \(error)")
                                clouser(error);
                            }
                        })
                    }
                })
            }
        }
        
        
    }
    
    func stopVPNTunnel() {
        self.providerManager?.connection.stopVPNTunnel();
    }
    
    private var vpnConnectionObserver: NSObjectProtocol?
    
    func stopVPNTunnel(clouser: @escaping () -> Void) {
        if let observer = vpnConnectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        self.providerManager?.connection.stopVPNTunnel();
        
        vpnConnectionObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
            
            let nevpnconn = notification.object as! NEVPNConnection
            let status = nevpnconn.status
            
            if status == .disconnected {
                if let observer = self?.vpnConnectionObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                clouser()
            }
        }
        
    }
    
    func getTraffictStats(){
        if let session = self.providerManager?.connection as? NETunnelProviderSession {
            do {
                try session.sendProviderMessage("OPENVPN_STATS".data(using: .utf8)!) {(data) in
                    //Do nothing
                }
            } catch {
                // some error
            }
        }
    }
}
