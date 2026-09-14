package com.adaptiveglass

import android.content.res.ColorStateList
import android.view.MotionEvent
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import android.widget.SeekBar
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import kotlin.math.roundToInt

private class SliderEvent(surfaceId: Int, tag: Int, private val kind: String, private val value: Double) : Event<SliderEvent>(surfaceId, tag) {
  override fun getEventName() = kind
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap().apply { putDouble("value", value) }
}

class ALGSliderView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  private val seekBar = SeekBar(reactContext)
  var controlledValue = 0.0
  var minimum = 0.0
  var maximum = 1.0
  var step = 0.0
  var disabled = false
  var glassTint: Int? = null
  var controlLabel: String? = null
  var controlHint: String? = null
  var controlTestID: String? = null
  private var dragging = false
  private var appliedMinimum = 0.0
  private var appliedMaximum = 1.0
  private var appliedStep = 0.0
  private var lastEmitted: Double? = null
  private val defaultTint = seekBar.progressTintList
  private val defaultThumbTint = seekBar.thumbTintList

  init {
    seekBar.max = 1000000
    addView(seekBar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
      override fun onStartTrackingTouch(bar: SeekBar) {
        if (disabled) return
        dragging = true
        lastEmitted = current()
        parent?.requestDisallowInterceptTouchEvent(true)
        emit("topSliderStart", current())
      }
      override fun onProgressChanged(bar: SeekBar, progress: Int, fromUser: Boolean) {
        if (!fromUser || disabled) return
        val value = current()
        if (!dragging) emit("topSliderStart", normalized(controlledValue))
        if (step > 0) position(value)
        if (value != lastEmitted) { lastEmitted = value; emit("topSliderChange", value) }
        if (!dragging) emit("topSliderComplete", value)
      }
      override fun onStopTrackingTouch(bar: SeekBar) {
        if (!dragging) return
        val value = current()
        dragging = false
        parent?.requestDisallowInterceptTouchEvent(false)
        emit("topSliderComplete", value)
      }
    })
    seekBar.setOnTouchListener { _, event ->
      if (event.actionMasked == MotionEvent.ACTION_CANCEL) cancel()
      false
    }
    seekBar.accessibilityDelegate = object : View.AccessibilityDelegate() {
      override fun performAccessibilityAction(host: View, action: Int, arguments: android.os.Bundle?): Boolean {
        if (disabled) return false
        val increment = if (step > 0) step else (maximum - minimum) / 20
        val next = when (action) {
          AccessibilityNodeInfo.ACTION_SCROLL_FORWARD -> normalized(controlledValue + increment)
          AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD -> normalized(controlledValue - increment)
          AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS.id -> {
            if (arguments == null || !arguments.containsKey(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE)) return false
            normalized(arguments.getFloat(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE).toDouble())
          }
          else -> return super.performAccessibilityAction(host, action, arguments)
        }
        emit("topSliderStart", normalized(controlledValue))
        position(next)
        if (next != normalized(controlledValue)) emit("topSliderChange", next)
        emit("topSliderComplete", next)
        return true
      }
      override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(host, info)
        info.rangeInfo = AccessibilityNodeInfo.RangeInfo.obtain(AccessibilityNodeInfo.RangeInfo.RANGE_TYPE_FLOAT,
          minimum.toFloat(), maximum.toFloat(), current().toFloat())
        if (android.os.Build.VERSION.SDK_INT >= 30) info.stateDescription = current().toString()
        else info.text = current().toString()
      }
    }
  }
  private fun normalized(value: Double): Double {
    val clamped = value.coerceIn(minimum, maximum)
    if (clamped == maximum || step == 0.0) return clamped
    // Match JS/Swift half-up rounding (the offset is always nonnegative).
    return (minimum + kotlin.math.floor((clamped - minimum) / step + 0.5) * step).coerceIn(minimum, maximum)
  }
  private fun current() = normalized(minimum + seekBar.progress / 1000000.0 * (maximum - minimum))
  private fun position(value: Double) { seekBar.progress = (((value - minimum) / (maximum - minimum)) * 1000000).roundToInt().coerceIn(0, 1000000) }
  private fun emit(kind: String, value: Double) {
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
      SliderEvent(UIManagerHelper.getSurfaceId(reactContext), id, kind, value))
  }
  private fun cancel() {
    if (!dragging) return
    dragging = false
    parent?.requestDisallowInterceptTouchEvent(false)
    position(normalized(controlledValue))
    emit("topSliderCancel", normalized(controlledValue))
  }
  fun applyConfiguration() {
    if (!listOf(controlledValue, minimum, maximum, step, maximum - minimum).all { it.isFinite() } || maximum <= minimum || step < 0 || step > maximum - minimum) return
    if (dragging && (disabled || minimum != appliedMinimum || maximum != appliedMaximum || step != appliedStep)) cancel()
    appliedMinimum = minimum; appliedMaximum = maximum; appliedStep = step
    seekBar.isEnabled = !disabled
    seekBar.contentDescription = controlLabel
    seekBar.tooltipText = controlHint
    seekBar.setTag(com.facebook.react.R.id.react_test_id, controlTestID)
    seekBar.progressTintList = glassTint?.let { ColorStateList.valueOf(it) } ?: defaultTint
    seekBar.thumbTintList = glassTint?.let { ColorStateList.valueOf(it) } ?: defaultThumbTint
    if (!dragging) position(normalized(controlledValue))
  }
  override fun onDetachedFromWindow() { cancel(); super.onDetachedFromWindow() }
}
