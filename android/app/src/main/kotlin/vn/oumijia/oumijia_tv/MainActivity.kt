package vn.oumijia.oumijia_tv

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Cầu nối độ sáng riêng cho cửa sổ ứng dụng.
 *
 * Chỉ đổi WindowManager.LayoutParams.screenBrightness của Activity này:
 * - Không đụng độ sáng toàn hệ thống, không cần quyền WRITE_SETTINGS.
 * - Khi rời app, cửa sổ các ứng dụng khác giữ nguyên độ sáng của chúng.
 * - Giá trị -1f = theo thiết lập của Android (BRIGHTNESS_OVERRIDE_NONE).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "oumijia_tv/brightness"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBrightness" -> {
                        val value = (call.arguments as? Number)?.toFloat()
                        if (value == null) {
                            result.error("bad_args", "Thiếu giá trị độ sáng", null)
                        } else {
                            try {
                                applyBrightness(value)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("brightness_failed", e.message, null)
                            }
                        }
                    }
                    "getBrightness" -> {
                        result.success(window.attributes.screenBrightness.toDouble())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyBrightness(value: Float) {
        val attrs = window.attributes
        attrs.screenBrightness = when {
            value < 0f -> WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            value > 1f -> 1f
            else -> value
        }
        window.attributes = attrs
    }
}
