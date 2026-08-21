package com.focusflow.planner

import android.content.Intent
import android.os.Bundle
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val deepLinkChannel = "focusflow/deep_link"
    private val wechatChannel = "focusflow/wechat"
    private val wechatAppId = "wx64ba2d4d4d4fb15370"
    private lateinit var wechatApi: IWXAPI
    private var pendingWeChatResult: MethodChannel.Result? = null
    private var pendingWeChatState: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = this
    }

    override fun onDestroy() {
        if (current === this) current = null
        pendingWeChatResult = null
        pendingWeChatState = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkChannel).apply {
            intent?.data?.toString()?.let { invokeMethod("onDeepLink", it) }
        }
        wechatApi = WXAPIFactory.createWXAPI(this, wechatAppId, true)
        wechatApi.registerApp(wechatAppId)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wechatChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInstalled" -> result.success(wechatApi.isWXAppInstalled)
                    "login" -> startWeChatLogin(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startWeChatLogin(result: MethodChannel.Result) {
        if (pendingWeChatResult != null) {
            result.error("WECHAT_BUSY", "A WeChat login is already in progress.", null)
            return
        }
        if (!wechatApi.isWXAppInstalled) {
            result.error("WECHAT_NOT_INSTALLED", "WeChat is not installed.", null)
            return
        }
        val state = "focusflow-${UUID.randomUUID()}"
        val request = SendAuth.Req().apply {
            scope = "snsapi_userinfo"
            this.state = state
        }
        pendingWeChatResult = result
        pendingWeChatState = state
        if (!wechatApi.sendReq(request)) {
            pendingWeChatResult = null
            pendingWeChatState = null
            result.error("WECHAT_REQUEST_FAILED", "Unable to open WeChat.", null)
        }
    }

    fun completeWeChatLogin(code: String?, state: String?, errorCode: Int, errorMessage: String?) {
        val result = pendingWeChatResult ?: return
        val expectedState = pendingWeChatState
        pendingWeChatResult = null
        pendingWeChatState = null
        if (errorCode == 0 && state != expectedState) {
            result.error("WECHAT_INVALID_STATE", "WeChat returned an invalid login state.", null)
            return
        }
        if (errorCode == 0 && !code.isNullOrEmpty()) {
            result.success(code)
        } else if (errorCode == -2) {
            result.error("WECHAT_CANCELLED", "WeChat login was cancelled.", null)
        } else {
            result.error("WECHAT_FAILED", errorMessage ?: "WeChat login failed.", null)
        }
    }

    companion object {
        var current: MainActivity? = null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.let { engine ->
            MethodChannel(engine.dartExecutor.binaryMessenger, deepLinkChannel)
                .invokeMethod("onDeepLink", intent.data?.toString() ?: "")
        }
    }
}
