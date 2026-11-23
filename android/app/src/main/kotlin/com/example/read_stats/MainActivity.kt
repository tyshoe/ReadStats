package com.tyshoe.readstats

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var backupFolder: BackupFolderChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    // The folder picker's result comes back here.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
