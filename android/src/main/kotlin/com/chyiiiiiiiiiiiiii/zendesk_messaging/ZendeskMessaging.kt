import android.content.Intent
import com.chyiiiiiiiiiiiiii.zendesk_messaging.ZendeskMessagingPlugin
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import zendesk.android.Zendesk
import zendesk.android.ZendeskResult
import zendesk.android.ZendeskUser
import zendesk.messaging.android.DefaultMessagingFactory
import zendesk.messaging.android.push.PushNotifications

class ZendeskMessaging(private val plugin: ZendeskMessagingPlugin, private val channel: MethodChannel) {
    companion object {
        const val tag = "[ZendeskMessaging]"

        // Method channel callback keys
        const val initializeSuccess: String = "initialize_success"
        const val initializeFailure: String = "initialize_failure"
        const val loginSuccess: String = "login_success"
        const val loginFailure: String = "login_failure"
        const val logoutSuccess: String = "logout_success"
        const val logoutFailure: String = "logout_failure"
        const val updateTokenSuccess: String = "update_token_success"
        const val updateTokenFailure: String = "update_token_failure"
        const val displayNotificationSuccess: String = "display_notification_success"
        const val displayNotificationFailure: String = "display_notification_failure"
    }


    fun initialize(channelKey: String) {
        println("$tag - Channel Key - $channelKey")
        Zendesk.initialize(
            plugin.activity!!,
            channelKey,
            successCallback = { value ->
                plugin.isInitialized = true;
                println("$tag - initialize success - $value")
                channel.invokeMethod(initializeSuccess, null)
            },
            failureCallback = { error ->
                plugin.isInitialized = false;
                println("$tag - initialize failure - $error")
                channel.invokeMethod(initializeFailure, mapOf("error" to error.message))
            },
            messagingFactory = DefaultMessagingFactory()
        )
    }

    fun show() {
        Zendesk.instance.messaging.showMessaging(plugin.activity!!, Intent.FLAG_ACTIVITY_NEW_TASK)
        println("$tag - show")
    }
    fun getUnreadMessageCount(): Int {
        return try {
            Zendesk.instance.messaging.getUnreadMessageCount()
        }catch (error: Throwable){
            0
        }
    }

    fun loginUser(jwt: String) {
        Zendesk.instance.loginUser(
            jwt,
            { value: ZendeskUser? ->
                value?.let {
                    channel.invokeMethod(loginSuccess, mapOf("id" to it.id, "externalId" to it.externalId))
                } ?: run {
                    channel.invokeMethod(loginSuccess, mapOf("id" to null, "externalId" to null))
                }
            },
            { error: Throwable? ->
                println("$tag - Login failure : ${error?.message}")
                println(error)
                channel.invokeMethod(loginFailure, mapOf("error" to error?.message))
            })
    }

    fun logoutUser() {
        GlobalScope.launch (Dispatchers.Main)  {
            try {
                val result = Zendesk.instance.logoutUser()
                if (result is ZendeskResult.Failure) {
                    channel.invokeMethod(logoutFailure, null)
                } else {
                    channel.invokeMethod(logoutSuccess, null)
                }
            } catch (error: Throwable) {
                println("$tag - Logout failure : ${error.message}")
                channel.invokeMethod(logoutFailure, mapOf("error" to error.message))
            }
        }
    }

    fun updatePushNotificationToken(token: String?) {
        try {
            PushNotifications.updatePushNotificationToken(token)
            channel.invokeMethod(updateTokenSuccess, null)
        } catch (error: Throwable) {
            println("$tag - Update token failure : ${error.message}")
            channel.invokeMethod(updateTokenFailure, mapOf("error" to error.message))
        }
    }

    fun handleRemoteMessage(data: Map<String, String>) {
        val responsibility = PushNotifications.shouldBeDisplayed(data)

        when (responsibility) {
            PushNotifications.PushResponsibility.MESSAGING_SHOULD_DISPLAY -> {
                PushNotifications.displayNotification(plugin.activity!!, data)
                channel.invokeMethod(displayNotificationSuccess, null)
            }
            PushNotifications.PushResponsibility.MESSAGING_SHOULD_NOT_DISPLAY -> {
                // This push belongs to Messaging but it should not be displayed to the end user
            }
            PushNotifications.PushResponsibility.NOT_FROM_MESSAGING -> {
                // This push does not belong to Messaging
            }
        }
    }
}


