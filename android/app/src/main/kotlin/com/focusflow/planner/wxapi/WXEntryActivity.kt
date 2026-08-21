package com.focusflow.planner.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.focusflow.planner.MainActivity
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

class WXEntryActivity : Activity(), IWXAPIEventHandler {
    private val appId = "wx64ba2d4d4d4fb15370"
    private lateinit var api: IWXAPI

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        api = WXAPIFactory.createWXAPI(this, appId, false)
        api.handleIntent(intent, this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        api.handleIntent(intent, this)
    }

    override fun onReq(req: BaseReq) = finish()

    override fun onResp(resp: BaseResp) {
        val authResp = resp as? SendAuth.Resp
        MainActivity.current?.completeWeChatLogin(authResp?.code, authResp?.state, resp.errCode, resp.errStr)
        finish()
    }
}