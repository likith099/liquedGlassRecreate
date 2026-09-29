package com.adaptiveglass

import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.NativeGestureUtil
import com.facebook.react.views.view.ReactViewGroup
import kotlin.math.hypot

private class LongPressEvent(surfaceId: Int, tag: Int, private val frame: FloatArray) : Event<LongPressEvent>(surfaceId, tag) {
  override fun getEventName() = "topLongPress"
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap().apply {
    putDouble("x", frame[0].toDouble()); putDouble("y", frame[1].toDouble())
    putDouble("width", frame[2].toDouble()); putDouble("height", frame[3].toDouble())
  }
}

/**
 * GlassLongPress on Android. The press is observed in dispatchTouchEvent without taking the touch,
 * so the children's taps and an enclosing list's scroll work until it is recognised. Then the
 * children's touches (native and JavaScript) are cancelled and the same finger is handed to the
 * latest GlassMenuPanel through ALGMenuPanelTracker.
 */
class ALGLongPressView(private val reactContext: ThemedReactContext) : ReactViewGroup(reactContext) {
  var minimumDuration = 500
  var allowableMovement = 10f
  var disabled = false
    set(value) { field = value; if (value) reset() }
  var haptic = "none"

  private val density = resources.displayMetrics.density
  private val handler = Handler(Looper.getMainLooper())
  private var downX = 0f
  private var downY = 0f
  private var last: MotionEvent? = null
  private var pending = false
  private var recognized = false
  private val recognize = Runnable { began() }

  private fun reset() {
    handler.removeCallbacks(recognize)
    pending = false
    recognized = false
    last?.recycle(); last = null
  }

  private fun remember(event: MotionEvent) { last?.recycle(); last = MotionEvent.obtain(event) }

  private fun began() {
    val event = last ?: return
    pending = false
    recognized = true
    if (haptic != "none") performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
    // Cancel the children: native views get ACTION_CANCEL, JavaScript responders a touch cancel,
    // so nothing inside fires onPress when the finger lifts. The list behind must not scroll now.
    NativeGestureUtil.notifyNativeGestureStarted(this, event)
    val cancel = MotionEvent.obtain(event).apply { action = MotionEvent.ACTION_CANCEL }
    super.dispatchTouchEvent(cancel)
    cancel.recycle()
    parent?.requestDisallowInterceptTouchEvent(true)
    ALGMenuPanelTracker.begin()
    val location = IntArray(2).also { getLocationInWindow(it) }
    val frame = floatArrayOf(location[0] / density, location[1] / density, width * scaleX / density, height * scaleY / density)
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
      LongPressEvent(UIManagerHelper.getSurfaceId(reactContext), id, frame))
  }

  override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    if (recognized) {
      when (event.actionMasked) {
        MotionEvent.ACTION_MOVE -> ALGMenuPanelTracker.move(event.rawX, event.rawY)
        MotionEvent.ACTION_UP -> { ALGMenuPanelTracker.end(event.rawX, event.rawY); finish(event) }
        MotionEvent.ACTION_CANCEL -> { ALGMenuPanelTracker.cancel(); finish(event) }
      }
      return true
    }
    if (!disabled) when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        reset()
        downX = event.rawX; downY = event.rawY
        remember(event)
        pending = true
        handler.postDelayed(recognize, minimumDuration.toLong())
      }
      MotionEvent.ACTION_MOVE -> if (pending) {
        remember(event)
        // Moving further than allowed fails the press, so a list can scroll instead.
        if (hypot(event.rawX - downX, event.rawY - downY) > allowableMovement * density) reset()
      }
      MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> reset()
    }
    return super.dispatchTouchEvent(event)
  }

  private fun finish(event: MotionEvent) {
    NativeGestureUtil.notifyNativeGestureEnded(this, event)
    reset()
  }

  override fun onDetachedFromWindow() {
    if (recognized) ALGMenuPanelTracker.cancel()
    reset()
    super.onDetachedFromWindow()
  }
}
