import UIKit
import ZendeskSDKMessaging
import ZendeskSDK

public class ZendeskMessaging: NSObject {
    private static var initializeSuccess: String = "initialize_success"
    private static var initializeFailure: String = "initialize_failure"
    private static var loginSuccess: String = "login_success"
    private static var loginFailure: String = "login_failure"
    private static var logoutSuccess: String = "logout_success"
    private static var logoutFailure: String = "logout_failure"
    
    let TAG = "[ZendeskMessaging]"
    
    private var zendeskPlugin: SwiftZendeskMessagingPlugin? = nil
    private var channel: FlutterMethodChannel? = nil

    init(flutterPlugin: SwiftZendeskMessagingPlugin, channel: FlutterMethodChannel) {
        self.zendeskPlugin = flutterPlugin
        self.channel = channel
    }
    
    func initialize(channelKey: String) {
        print("\(self.TAG) - Channel Key - \(channelKey)\n")
        Zendesk.initialize(withChannelKey: channelKey, messagingFactory: DefaultMessagingFactory()) { result in
            if case let .failure(error) = result {
                self.zendeskPlugin?.isInitialized = false
                print("\(self.TAG) - initialize failure - \(error.localizedDescription)\n")
                self.channel?.invokeMethod(ZendeskMessaging.initializeFailure, arguments: ["error": error.localizedDescription])
            } else {
                self.zendeskPlugin?.isInitialized = true
                print("\(self.TAG) - initialize success")
                self.channel?.invokeMethod(ZendeskMessaging.initializeSuccess, arguments: [:])
            }
        }
    }

    func show(rootViewController: UIViewController?) {
        guard let messagingViewController = Zendesk.instance?.messaging?.messagingViewController() else { return }
        guard let rootViewController = rootViewController else { return }
        rootViewController.present(messagingViewController, animated: true, completion: nil)
        print("\(self.TAG) - show")
    }
    
    func loginUser(jwt: String) {
        Zendesk.instance?.loginUser(with: jwt) { result in
            switch result {
            case .success(let user):
                self.channel?.invokeMethod(ZendeskMessaging.loginSuccess, arguments: ["id": user.id, "externalId": user.externalId])
                break;
            case .failure(let error):
                print("\(self.TAG) - login failure - \(error.localizedDescription)\n")
                self.channel?.invokeMethod(ZendeskMessaging.loginFailure, arguments: ["error": nil])
                break;
            }
        }
    }
    
    func logoutUser() {
        Zendesk.instance?.logoutUser { result in
            switch result {
            case .success:
                self.channel?.invokeMethod(ZendeskMessaging.logoutSuccess, arguments: [])
                break;
            case .failure(let error):
                print("\(self.TAG) - logout failure - \(error.localizedDescription)\n")
                self.channel?.invokeMethod(ZendeskMessaging.logoutFailure, arguments: ["error": nil])
                break;
            }
        }
    }
    func getUnreadMessageCount() -> Int {
        let count = Zendesk.instance?.messaging?.getUnreadMessageCount()
        return count ?? 0
    }
    // Add this method to register for push notifications
    func registerForPushNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
            guard allowed else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // Add this method to update the PushNotifications class with the received device token
    func updatePushNotificationToken(deviceToken: Data) {
        PushNotifications.updatePushNotificationToken(deviceToken)
    }
    
    // UNUserNotificationCenterDelegate methods
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        // This checks whether a received push notification should be displayed by Messaging
        let shouldBeDisplayed = PushNotifications.shouldBeDisplayed(userInfo)

        switch shouldBeDisplayed {
        case .messagingShouldDisplay:
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        case .messagingShouldNotDisplay:
            completionHandler([])
        case .notFromMessaging:
            completionHandler([])
        @unknown default: break
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        let shouldBeDisplayed = PushNotifications.shouldBeDisplayed(userInfo)

        switch shouldBeDisplayed {
        case .messagingShouldDisplay:
            PushNotifications.handleTap(userInfo) { viewController in
                // Handle displaying the returned viewController in here
            }
        case .messagingShouldNotDisplay:
            break
        case .notFromMessaging:
            break
        @unknown default: break
        }

        completionHandler()
    }
}
