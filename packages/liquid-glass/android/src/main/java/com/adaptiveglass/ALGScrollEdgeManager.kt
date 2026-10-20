package com.adaptiveglass

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RenderEffect
import android.graphics.RenderNode
import android.graphics.Shader
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.viewmanagers.ALGScrollEdgeManagerDelegate
import com.facebook.react.viewmanagers.ALGScrollEdgeManagerInterface
import com.facebook.react.views.view.ReactViewGroup

/** Only the linked scrolling content is blurred; header children remain sharp and interactive. */
class ALGScrollEdgeView(context: ThemedReactContext) : ReactViewGroup(context) {
  var scrollTag = -1
  var edge = "bottom"
  var mode = "gradient"
  var fill: Int? = null
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
  private var node: RenderNode? = null
  private val ownPosition = IntArray(2)
  private val targetPosition = IntArray(2)
  private var observer: ViewTreeObserver? = null
  private var lastTargetState: List<Int>? = null
  private val scrollListener = ViewTreeObserver.OnScrollChangedListener { if (mode == "blur") invalidate() }
  private val preDrawListener = ViewTreeObserver.OnPreDrawListener {
    if (mode == "blur" && Build.VERSION.SDK_INT >= 31) {
      val target = target()
      target?.getLocationInWindow(targetPosition)
      getLocationInWindow(ownPosition)
      val state = listOf(scrollTag, targetPosition[0] - ownPosition[0], targetPosition[1] - ownPosition[1],
        target?.scrollX ?: 0, target?.scrollY ?: 0, width, height)
      // Do not run an idle animation loop: update only when the source or geometry changes.
      if (target?.isDirty == true || state != lastTargetState) { lastTargetState = state; invalidate() }
    }
    true
  }
  private fun target(): View? {
    if (scrollTag <= 0) return null
    val target = rootView.findViewById<View>(scrollTag) ?: return null
    // A header belongs beside its ScrollView, never within its capture source.
    var ancestor: android.view.ViewParent? = this
    while (ancestor != null) { if (ancestor === target) return null; ancestor = ancestor.parent }
    return target.takeIf { it.isAttachedToWindow && it.width > 0 && it.height > 0 }
  }
  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    observer = viewTreeObserver.also { it.addOnScrollChangedListener(scrollListener); it.addOnPreDrawListener(preDrawListener) }
  }
  override fun onDetachedFromWindow() {
    observer?.takeIf { it.isAlive }?.let { it.removeOnScrollChangedListener(scrollListener); it.removeOnPreDrawListener(preDrawListener) }
    observer = null; lastTargetState = null
    if (Build.VERSION.SDK_INT >= 29) node?.discardDisplayList()
    node = null
    super.onDetachedFromWindow()
  }
  private fun drawBlur(canvas: Canvas, color: Int): Boolean {
    if (Build.VERSION.SDK_INT < 31 || !canvas.isHardwareAccelerated) return false
    val source = target() ?: return false
    source.getLocationInWindow(targetPosition); getLocationInWindow(ownPosition)
    val render = node ?: RenderNode("GlassScrollHeader backdrop").also { node = it }
    render.setPosition(0, 0, width, height)
    val radius = 20f * resources.displayMetrics.density
    render.setRenderEffect(RenderEffect.createBlurEffect(radius, radius, Shader.TileMode.CLAMP))
    val recording = render.beginRecording(width, height)
    try {
      recording.drawColor(color or Color.BLACK)
      recording.translate((targetPosition[0] - ownPosition[0] - source.scrollX).toFloat(), (targetPosition[1] - ownPosition[1] - source.scrollY).toFloat())
      source.draw(recording)
    } finally { render.endRecording() }
    canvas.drawRenderNode(render)
    paint.shader = null; paint.color = (color and 0x00ffffff) or (48 shl 24)
    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    return true
  }
  override fun dispatchDraw(canvas: Canvas) {
    val dark = resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK == android.content.res.Configuration.UI_MODE_NIGHT_YES
    val color = fill ?: if (dark) Color.rgb(18, 20, 26) else Color.rgb(247, 248, 252)
    if (width > 0 && height > 0) {
      val blurred = mode == "blur" && drawBlur(canvas, color)
      if (!blurred && (mode != "gradient" || fill != null)) {
        paint.shader = if (mode == "gradient") LinearGradient(0f, 0f, 0f, height.toFloat(),
          if (edge == "top") color else color and 0x00ffffff,
          if (edge == "top") color and 0x00ffffff else color, Shader.TileMode.CLAMP) else null
        paint.color = color or Color.BLACK // solid is intentionally opaque
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        paint.shader = null
      }
    }
    super.dispatchDraw(canvas)
  }
}

@ReactModule(name = "ALGScrollEdge")
class ALGScrollEdgeManager : ViewGroupManager<ALGScrollEdgeView>(), ALGScrollEdgeManagerInterface<ALGScrollEdgeView> {
  private val delegate = ALGScrollEdgeManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGScrollEdge"
  override fun createViewInstance(context: ThemedReactContext) = ALGScrollEdgeView(context)
  override fun setScrollViewTag(view: ALGScrollEdgeView, value: Int) { view.scrollTag = value }
  override fun setEdge(view: ALGScrollEdgeView, value: String?) { view.edge = value ?: "bottom" }
  override fun setEffectStyle(view: ALGScrollEdgeView, value: String?) = Unit
  override fun setFallbackMode(view: ALGScrollEdgeView, value: String?) { view.mode = value ?: "gradient" }
  override fun setFallbackColor(view: ALGScrollEdgeView, value: Int?) { view.fill = value }
  override fun onAfterUpdateTransaction(view: ALGScrollEdgeView) { super.onAfterUpdateTransaction(view); view.invalidate() }
}
