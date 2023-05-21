import Flutter
import UIKit
import NetworkExtension

public class SwiftOpenVPNFlutterPlugin: NSObject, FlutterPlugin {
    static var utils : VPNUtils = VPNUtils()
    
    private static var EVENT_CHANNEL_VPN_CONNECTION : String = "id.laskarmedia.openvpn_flutter/vpnstage"
    private static var EVENT_CHANNEL_VPN_TRAFFIC : String = "id.laskarmedia.openvpn_flutter/vpn_traffic"
    private static var METHOD_CHANNEL_VPN_CONTROL : String = "id.laskarmedia.openvpn_flutter/vpncontrol"
    
    private var initialized : Bool = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftOpenVPNFlutterPlugin()
        instance.onRegister(registrar)
    }
    
    public func onRegister(_ registrar: FlutterPluginRegistrar){
        let vpnControlMethod = FlutterMethodChannel(name: SwiftOpenVPNFlutterPlugin.METHOD_CHANNEL_VPN_CONTROL, binaryMessenger: registrar.messenger())
        let vpnConnectionEvent = FlutterEventChannel(name: SwiftOpenVPNFlutterPlugin.EVENT_CHANNEL_VPN_CONNECTION, binaryMessenger: registrar.messenger())
        let vpnTrafficEvent = FlutterEventChannel(name: SwiftOpenVPNFlutterPlugin.EVENT_CHANNEL_VPN_TRAFFIC, binaryMessenger: registrar.messenger())
        
        vpnConnectionEvent.setStreamHandler(VPNConnectionHandler())
        vpnTrafficEvent.setStreamHandler(VPNTrafficHandler())
        
        vpnControlMethod.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method{
            case "status":
                self.status(arguments: call.arguments, completion: result)
                break;
                
            case "stage":
                self.stage(arguments: call.arguments, completion: result)
                break;
                
            case "initialize":
                self.initialize(arguments: call.arguments, completion: result)
                break;
                
            case "disconnect":
                self.disconnect(arguments: call.arguments, completion: result)
                break;
                
            case "connect":
                self.connect(arguments: call.arguments, completion: result)
                break;
                
            case "dispose":
                self.dispose(arguments: call.arguments, completion: result)
                break;
                
            default:
                break;
                
            }
        })
    }
    
    private func status(arguments: Any?, completion: @escaping (Any?) -> Void) {
        completion(SwiftOpenVPNFlutterPlugin.utils.currentTraffic())
    }
    
    
    private func stage(arguments: Any?, completion: @escaping (Any?) -> Void) {
        completion(SwiftOpenVPNFlutterPlugin.utils.currentStatus())
    }
    
    private func initialize(arguments: Any?, completion: @escaping (Any?) -> Void) {
        guard let argument = arguments as? [String: Any] else {
            self.initialized = false
            completion(FlutterError(code: "", message: "argument is nil", details: nil))
            return
        }
        
        SwiftOpenVPNFlutterPlugin.utils.initialize(arguments: argument) { error in
            if let error = error {
                self.initialized = false
                completion(FlutterError(code: "", message: "\(error)", details: nil))
            } else {
                self.initialized = true
                completion(nil)
            }
        }
    }
    
    private func connect(arguments: Any?, completion: @escaping (Any?) -> Void) {
        if self.initialized == false {
            completion(FlutterError(code: "", message: "VPNEngine need to be initialize", details: nil));
        } else {

            guard let arguments = arguments as? [String: Any]
            else {
                completion(FlutterError(code: "", message: "arguments is empty or null", details: nil));
                return
            }
            
            SwiftOpenVPNFlutterPlugin.utils.startVPNTunnel(arguments: arguments) {
                error in
                if(error == nil){
                    completion(nil)
                }else{
                    completion(FlutterError(code: "", message: "\(String(describing: error))", details: nil))
                }
            }
        }
    }
    
    private func disconnect(arguments: Any?, completion: @escaping (Any?) -> Void) {
        SwiftOpenVPNFlutterPlugin.utils.stopVPNTunnel()
    }
    
    private func dispose(arguments: Any?, completion: (Any?) -> Void) {
        self.initialized = false
    }
    
}

class VPNConnectionHandler: NSObject, FlutterStreamHandler {
    private var vpnConnection: FlutterEventSink?
    private var vpnConnectionObserver: NSObjectProtocol?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Remove existing observer if any
        if let observer = vpnConnectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        vpnConnectionObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
            guard let self = self, let connection = self.vpnConnection else {
                // Check if self or connection is nil and return early if that's the case
                return
            }
            
            let nevpnconn = notification.object as! NEVPNConnection
            let status = nevpnconn.status
            
            // Send the event using the eventSink closure
            connection(SwiftOpenVPNFlutterPlugin.utils.onVpnStatusChangedString(notification: status))
        }
        
        // Assign the eventSink closure to the vpnConnection variable
        self.vpnConnection = events
        
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            events(SwiftOpenVPNFlutterPlugin.utils.onVpnStatusChangedString(notification: managers?.first?.connection.status))
        }
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // Remove existing observer if any
        if let observer = vpnConnectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Set vpnConnection to nil when the observer is removed
        vpnConnection = nil
        
        return nil
    }
}

class VPNTrafficHandler: NSObject, FlutterStreamHandler {
    private var vpnTraffic: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        
        vpnTraffic = events
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        
        vpnTraffic = nil
        
        return nil
    }
}

