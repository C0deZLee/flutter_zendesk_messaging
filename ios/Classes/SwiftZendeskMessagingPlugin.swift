import Flutter
import UIKit

public class SwiftZendeskMessagingPlugin: NSObject, FlutterPlugin {
    let TAG = "[SwiftZendeskMessagingPlugin]"
    private var channel: FlutterMethodChannel
    var isInitialized = false
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "zendesk_messaging", binaryMessenger: registrar.messenger())
        let instance = SwiftZendeskMessagingPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments as? Dictionary<String, Any>
        let zendeskMessaging = ZendeskMessaging(flutterPlugin: self, channel: channel)

        // chat sdk method channels
        switch(method){
            case "initialize":
                if (isInitialized) {
                    print("\(TAG) - Messaging is already initialize!\n")
                    return
                }
                let channelKey: String = (arguments?["channelKey"] ?? "") as! String
                zendeskMessaging.initialize(channelKey: channelKey)
                break;
            case "show":
                if (!isInitialized) {
                    print("\(TAG) - Messaging needs to be initialized first.\n")
                }
                zendeskMessaging.show(rootViewController: UIApplication.shared.delegate?.window??.rootViewController)
                break
            case "loginUser":
                if (!isInitialized) {
                    print("\(TAG) - Messaging needs to be initialized first.\n")
                }
                let jwt: String = arguments?["jwt"] as! String
                zendeskMessaging.loginUser(jwt: jwt)
                break
            case "logoutUser":
                if (!isInitialized) {
                    print("\(TAG) - Messaging needs to be initialized first.\n")
                }
                zendeskMessaging.logoutUser()
                break
            case "getUnreadMessageCount":
                if (!isInitialized) {
                    print("\(TAG) - Messaging needs to be initialized first.\n")
                }
                result(handleMessageCount())
                break
            
            case "isInitialized":
                result(handleInitializedStatus())
                break

            // Add this case to handle the "updatePushNotificationToken" call
            case "updatePushNotificationToken":
                if (!isInitialized) {
                    print("\(TAG) - Messaging needs to be initialized first.\n")
                }
                let deviceToken: String = (arguments?["deviceToken"] ?? "") as! String
                zendeskMessaging.updatePushNotificationToken(deviceToken: deviceToken)
                break

            // TODO: Add this case to handle the "handleRemoteMessage" call
            case "handleZendeskNotification":
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? [String: String] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments. Expected 'data' as a dictionary.", details: nil))
                    return
                }
                zendeskMessaging.handleZendeskNotification(data: data)
                break

            default:
                break
        }

        result(nil)
    }

    private func handleMessageCount() ->Int{
         let zendeskMessaging = ZendeskMessaging(flutterPlugin: self, channel: channel)

        return zendeskMessaging.getUnreadMessageCount()
    }
    private func handleInitializedStatus() ->Bool{
        return isInitialized
    }
    
}
