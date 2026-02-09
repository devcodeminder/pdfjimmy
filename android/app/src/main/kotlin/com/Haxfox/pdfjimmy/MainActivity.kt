package com.Haxfox.pdfjimmy

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onActionModeStarted(mode: android.view.ActionMode?) {
        mode?.menu?.clear()
        super.onActionModeStarted(mode)
        mode?.finish()
    }
}
