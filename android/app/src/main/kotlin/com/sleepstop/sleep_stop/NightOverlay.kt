package com.sleepstop.sleep_stop

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen black "night veil" drawn over the media app at minimum screen
 * brightness (requires the user-granted "display over other apps" permission).
 *
 * On an OLED this makes the screen look off immediately without leaving the
 * media app, so a tap ("still awake") can resume playback where it stopped.
 * Once the system turns the display off (no app holds a wake lock anymore),
 * the veil removes itself so the user never wakes up to a black window.
 */
object NightOverlay {
    private var windowManager: WindowManager? = null
    private var root: FrameLayout? = null
    private var titleView: TextView? = null
    private var hintView: TextView? = null
    private var countdownView: TextView? = null
    private var screenOffReceiver: BroadcastReceiver? = null
    private var tapEnabled = true
    private val mainHandler = Handler(Looper.getMainLooper())

    fun canDraw(context: Context): Boolean = Settings.canDrawOverlays(context)

    fun isShowing(): Boolean = root != null

    /** Shows the veil. [onTap] is invoked (once) when the user touches it. */
    fun show(
        context: Context,
        title: String,
        hint: String,
        countdown: String,
        onTap: () -> Unit
    ) {
        if (!canDraw(context)) return
        mainHandler.post {
            if (root != null) {
                titleView?.text = title
                hintView?.text = hint
                countdownView?.text = countdown
                tapEnabled = true
                return@post
            }
            val appContext = context.applicationContext
            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            val container = FrameLayout(appContext).apply {
                setBackgroundColor(Color.BLACK)
                isClickable = true
                isFocusable = false
            }
            val column = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                val pad = dp(appContext, 32f)
                setPadding(pad, pad, pad, pad)
            }
            titleView = dimText(appContext, title, 15f, 0x66DCD8D0)
            hintView = dimText(appContext, hint, 12.5f, 0x448C8881)
            countdownView = dimText(appContext, countdown, 12f, 0x55FF9E44)
            column.addView(titleView)
            column.addView(spacer(appContext, 10f))
            column.addView(hintView)
            column.addView(spacer(appContext, 18f))
            column.addView(countdownView)
            container.addView(
                column,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER
                )
            )
            container.setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_UP && tapEnabled) {
                    tapEnabled = false
                    onTap()
                }
                true
            }

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR,
                PixelFormat.OPAQUE
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                // Dimmest the panel can go while still "on"; the system timeout
                // then switches the display off once no wake lock remains.
                screenBrightness = 0.0f
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
            @Suppress("DEPRECATION")
            container.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )

            try {
                wm.addView(container, params)
                root = container
                tapEnabled = true
                registerScreenOff(appContext)
            } catch (_: Exception) {
                root = null
            }
        }
    }

    fun update(countdown: String?, title: String? = null, hint: String? = null) {
        mainHandler.post {
            countdown?.let { countdownView?.text = it }
            title?.let { titleView?.text = it }
            hint?.let { hintView?.text = it }
        }
    }

    /** Final state: no more tap-to-resume, just a quiet good-night veil. */
    fun setFinal(title: String, hint: String) {
        mainHandler.post {
            tapEnabled = false
            titleView?.text = title
            hintView?.text = hint
            countdownView?.text = ""
        }
    }

    fun hide(context: Context) {
        mainHandler.post {
            val view = root ?: return@post
            root = null
            try {
                windowManager?.removeViewImmediate(view)
            } catch (_: Exception) {
            }
            unregisterScreenOff(context.applicationContext)
        }
    }

    private fun registerScreenOff(context: Context) {
        if (screenOffReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_SCREEN_OFF) {
                    hide(ctx)
                }
            }
        }
        screenOffReceiver = receiver
        try {
            context.registerReceiver(receiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        } catch (_: Exception) {
            screenOffReceiver = null
        }
    }

    private fun unregisterScreenOff(context: Context) {
        val receiver = screenOffReceiver ?: return
        screenOffReceiver = null
        try {
            context.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
    }

    private fun dimText(context: Context, text: String, sp: Float, argb: Int): TextView {
        return TextView(context).apply {
            this.text = text
            setTextColor(argb)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.25f)
        }
    }

    private fun spacer(context: Context, dpValue: Float): View {
        return View(context).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(context, dpValue))
        }
    }

    private fun dp(context: Context, value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.resources.displayMetrics
        ).toInt()
    }
}
