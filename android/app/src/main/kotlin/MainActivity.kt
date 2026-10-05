// Kotlin doesn't require the folder to match the package, so this lives
// at a short path. The old com/example/... copy is removed by
// tool/setup_and_analyze.bat.
package com.nexted.ieltsai

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Debug
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * Content protection for store builds. The manifest flag `nexted.secure`
 * is true for release/profile builds and false for debug builds
 * (build.gradle.kts), so `flutter run` keeps screenshots for development.
 */
class MainActivity : FlutterActivity() {
    private val secure: Boolean by lazy {
        try {
            packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                .metaData?.getBoolean("nexted.secure", true) ?: true
        } catch (_: Exception) {
            true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (secure) {
            // Blocks screenshots, screen recording, casting / mirroring of
            // the app's screens (they show black) and the recent-apps preview.
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        super.onCreate(savedInstanceState)
        if (secure && tampered()) finishAndRemoveTask()
    }

    override fun onResume() {
        super.onResume()
        if (secure && tampered()) finishAndRemoveTask()
    }

    /** A store build is never debuggable and never has a debugger attached.
     *  Either means the APK was rebuilt or is being inspected: close. */
    private fun tampered(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0 ||
            Debug.isDebuggerConnected() ||
            Debug.waitingForDebugger()
}
