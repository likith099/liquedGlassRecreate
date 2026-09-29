package com.adaptiveglass

import android.animation.ValueAnimator
import android.content.res.Configuration
import android.graphics.Outline
import android.graphics.drawable.GradientDrawable
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.ViewTreeObserver
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray
import java.lang.ref.WeakReference
import kotlin.math.max
import kotlin.math.roundToInt

private class PanelEvent(surfaceId: Int, tag: Int, private val name: String, private val itemId: String? = null) :
  Event<PanelEvent>(surfaceId, tag) {
  override fun getEventName() = name
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap().apply { itemId?.let { putString("id", it) } }
}

/**
 * Hands a long press's finger to the most recently attached menu panel, in screen pixels. A point
 * that arrives before any panel is attached is kept and applied when one attaches.
 */
internal object ALGMenuPanelTracker {
  private val panels = mutableListOf<WeakReference<ALGMenuPanelView>>()
  private var active = false
  private var pending: Pair<Float, Float>? = null
  private val current: ALGMenuPanelView?
    get() { panels.removeAll { it.get() == null }; return panels.lastOrNull()?.get() }
  fun register(panel: ALGMenuPanelView) {
    panels.removeAll { it.get() == null || it.get() === panel }
    panels.add(WeakReference(panel))
    val point = pending
    if (active && point != null) panel.trackExternal(point.first, point.second)
  }
  fun unregister(panel: ALGMenuPanelView) { panels.removeAll { it.get() == null || it.get() === panel } }
  /** The long press was recognised; the finger is still down. */
  fun begin() { active = true; pending = null }
  fun move(x: Float, y: Float) {
    if (!active) return
    pending = x to y
    current?.trackExternal(x, y)
  }
  /** The finger lifted: choose the row under it, if any. */
  fun end(x: Float, y: Float) {
    if (!active) return
    active = false; pending = null
    current?.endExternal(x, y)
  }
  fun cancel() {
    if (!active) return
    active = false; pending = null
    current?.cancelHighlight()
  }
}

/**
 * GlassMenuPanel on Android: the package's menu popup look (MenuStyle, MenuRowViews) drawn in place,
 * laid out by React Native. Rows have fixed heights so JavaScript's GlassMenuPanel.measure matches.
 * A finger highlights the row under it with the ripple, sliding moves it with a tick, and lifting
 * on an enabled row reports the action.
 */
class ALGMenuPanelView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  var itemsJSON = "[]"
  var fontScale = 1f
  var colorScheme = "system"
  var disabled = false
  var appearFrom = "none"
  var autoFocus = false
  var menuModal = false
  var menuStyleJSON = ""
  var controlTestID: String? = null

  private val density = resources.displayMetrics.density
  private fun dp(value: Float) = (value * density).roundToInt()
  private val content = LinearLayout(reactContext).apply { orientation = LinearLayout.VERTICAL }
  private val scroll = ScrollView(reactContext).apply {
    isVerticalScrollBarEnabled = false
    overScrollMode = View.OVER_SCROLL_NEVER
    addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
  }
  private var rows = emptyList<Pair<MenuRow, MenuEntry>>()
  private var style: MenuStyle? = null
  private var applied: List<Any?>? = null
  private var highlighted: MenuRow? = null
  private var tracking = false
  private var downScroll = 0
  private var appeared = false

  init {
    addView(scroll, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    // Clip the rows' ripples to the rounded surface.
    outlineProvider = object : ViewOutlineProvider() {
      override fun getOutline(view: View, outline: Outline) =
        outline.setRoundRect(0, 0, view.width, view.height, (style?.cornerRadius ?: 16f) * density)
    }
    clipToOutline = true
    elevation = 8f * density
  }

  private fun isDark() = when (colorScheme) {
    "dark" -> true
    "light" -> false
    else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
  }

  private fun decode(array: JSONArray): List<MenuEntry> = (0 until array.length()).map { index ->
    val item = array.getJSONObject(index)
    MenuEntry(item.getString("id"), item.getString("title"), item.optString("kind", "action"),
      item.optBoolean("disabled"), item.optBoolean("destructive"),
      if (item.has("checked")) item.getBoolean("checked") else null,
      item.optJSONArray("items")?.let { decode(it) } ?: emptyList(), "automatic", item.optString("androidIcon"))
  }

  fun applyConfiguration() {
    setTag(com.facebook.react.R.id.react_test_id, controlTestID)
    val dark = isDark()
    val configuration = listOf(itemsJSON, fontScale, dark, disabled, menuStyleJSON)
    if (configuration == applied) return
    applied = configuration
    cancelHighlight()
    val next = MenuStyle.from(menuStyleJSON, dark)
    style = next
    background = GradientDrawable().apply { setColor(next.background); cornerRadius = next.cornerRadius * density }
    invalidateOutline()
    val entries = try { decode(JSONArray(itemsJSON)) } catch (_: Exception) { emptyList() }
    val views = MenuRowViews(context, next, null)
    val scale = max(1f, fontScale)
    val reserveIcon = flatten(entries).any { it.androidIcon.isNotEmpty() }
    content.removeAllViews()
    content.setPadding(0, dp(8f), 0, dp(8f))
    val built = mutableListOf<Pair<MenuRow, MenuEntry>>()
    // Sections become an optional title between dividers, as in the popup and in measure().
    var lastDivider = true
    fun add(view: View, height: Int) = content.addView(view, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, height))
    fun divider() { add(views.divider(), dp(17f)); lastDivider = true }
    fun lines(nodes: List<MenuEntry>) {
      for (entry in nodes) {
        if (entry.kind == "section") {
          if (content.childCount > 0 && !lastDivider) divider()
          if (entry.title.isNotEmpty()) { add(views.title(entry.title), dp(36f * scale)); lastDivider = false }
          lines(entry.items)
          if (!lastDivider) divider()
        } else {
          val enabled = !disabled && !entry.disabled
          val row = views.item(entry, enabled, reserveIcon).apply {
            background = views.ripple()
            accessibilityDelegate = RowAccessibility(entry, enabled)
          }
          add(row, dp(52f * scale)); built.add(row to entry); lastDivider = false
        }
      }
    }
    lines(entries)
    while (content.childCount > 0 && content.getChildAt(content.childCount - 1).importantForAccessibility ==
      View.IMPORTANT_FOR_ACCESSIBILITY_NO && content.getChildAt(content.childCount - 1) !is MenuRow) {
      content.removeViewAt(content.childCount - 1)
    }
    rows = built
    requestLayout()
  }

  private fun flatten(nodes: List<MenuEntry>): List<MenuEntry> = nodes.flatMap { if (it.kind == "section") flatten(it.items) else listOf(it) }

  /** TalkBack: each row is a button that reports destructive and disabled states and can be activated. */
  private inner class RowAccessibility(private val entry: MenuEntry, private val enabled: Boolean) : View.AccessibilityDelegate() {
    override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
      super.onInitializeAccessibilityNodeInfo(host, info)
      info.className = Button::class.java.name
      info.isEnabled = enabled
      if (entry.destructive && android.os.Build.VERSION.SDK_INT >= 30) info.stateDescription = "Destructive"
      if (enabled) info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_CLICK)
    }
    override fun performAccessibilityAction(host: View, action: Int, args: android.os.Bundle?): Boolean {
      if (action == AccessibilityNodeInfo.ACTION_CLICK && enabled) { choose(entry); return true }
      return super.performAccessibilityAction(host, action, args)
    }
  }

  // Fabric sets this view's frame but never measures its native children, so lay them out here.
  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    scroll.measure(MeasureSpec.makeMeasureSpec(right - left, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(bottom - top, MeasureSpec.EXACTLY))
    scroll.layout(0, 0, right - left, bottom - top)
  }
  private val relayout = Runnable { if (width > 0) { measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
    MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)); layout(left, top, right, bottom) } }
  override fun requestLayout() { super.requestLayout(); post(relayout) }

  private val scrollable get() = content.height > scroll.height

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    ALGMenuPanelTracker.register(this)
    if (appeared) return
    appeared = true
    // The entrance starts from the very first frame. Its starting state is set here, before
    // anything is drawn, and the animation starts just before the first draw, once Fabric has
    // given the view its size. (Setting the state in a posted callback let one frame draw at full
    // opacity first: the panel flashed, vanished and faded back in.)
    val animated = (appearFrom == "top" || appearFrom == "bottom") && ValueAnimator.areAnimatorsEnabled()
    if (animated) { scaleX = 0.9f; scaleY = 0.9f; alpha = 0f }
    val listener = object : ViewTreeObserver.OnPreDrawListener {
      override fun onPreDraw(): Boolean {
        if (width == 0 || height == 0) return true
        removeEntranceListener()
        appear(animated)
        return true
      }
    }
    entranceListener = listener
    viewTreeObserver.addOnPreDrawListener(listener)
  }
  override fun onDetachedFromWindow() {
    removeEntranceListener()
    ALGMenuPanelTracker.unregister(this)
    super.onDetachedFromWindow()
  }
  private var entranceListener: ViewTreeObserver.OnPreDrawListener? = null
  private fun removeEntranceListener() {
    entranceListener?.let { if (viewTreeObserver.isAlive) viewTreeObserver.removeOnPreDrawListener(it) }
    entranceListener = null
  }

  private fun appear(animated: Boolean) {
    if (autoFocus) rows.firstOrNull { it.first.isEnabled }?.first?.let { row ->
      row.performAccessibilityAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS, null)
      row.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
    }
    if (menuModal) accessibilityPaneTitle = contentDescription ?: "Menu"
    if (!animated) return
    pivotX = width / 2f
    pivotY = if (appearFrom == "top") 0f else height.toFloat()
    animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(220)
      .setInterpolator(android.view.animation.DecelerateInterpolator()).start()
  }

  /** Shrinks toward the edge it opened from, then reports the end. */
  fun dismiss() {
    cancelHighlight()
    if (!ValueAnimator.areAnimatorsEnabled()) { dispatch("topDismissed"); return }
    pivotY = if (appearFrom == "bottom") height.toFloat() else 0f
    animate().scaleX(0.92f).scaleY(0.92f).alpha(0f).setDuration(150)
      .withEndAction { dispatch("topDismissed") }.start()
  }

  private fun dispatch(name: String, itemId: String? = null) {
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
      PanelEvent(UIManagerHelper.getSurfaceId(reactContext), id, name, itemId))
  }

  private fun choose(entry: MenuEntry) {
    if (!disabled && !entry.disabled) dispatch("topMenuAction", entry.id)
  }

  // MARK: Tracking

  /** The row under a point in this view's coordinates. */
  private fun rowAt(x: Float, y: Float): Pair<MenuRow, MenuEntry>? {
    if (x < 0 || y < 0 || x >= width || y >= height) return null
    val inContent = y - scroll.top + scroll.scrollY - content.top
    return rows.firstOrNull { inContent >= it.first.top && inContent < it.first.bottom }
  }

  private fun press(x: Float, y: Float, tick: Boolean) {
    val target = rowAt(x, y)?.first?.takeIf { it.isEnabled }
    if (target === highlighted) {
      target?.drawableHotspotChanged(x, y - target.top)
      return
    }
    highlighted?.isPressed = false
    highlighted = target
    if (target != null) {
      target.drawableHotspotChanged(x, y - scroll.top + scroll.scrollY - content.top - target.top)
      target.isPressed = true
      if (tick) performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }
  }

  private fun finish(x: Float, y: Float) {
    val target = rowAt(x, y)
    cancelHighlight()
    if (target != null && target.first.isEnabled && !disabled) dispatch("topMenuAction", target.second.id)
    else dispatch("topCancelTouch")
  }

  fun cancelHighlight() {
    highlighted?.isPressed = false
    highlighted = null
  }

  override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        tracking = true
        downScroll = scroll.scrollY
        // Dragging across the menu selects rows; it does not scroll what is behind it.
        parent?.requestDisallowInterceptTouchEvent(true)
        press(event.x, event.y, tick = false)
      }
      MotionEvent.ACTION_MOVE -> if (tracking) {
        // Once the rows scroll, the touch is a scroll, not a selection.
        if (scroll.scrollY != downScroll) { tracking = false; cancelHighlight() } else press(event.x, event.y, tick = true)
      }
      MotionEvent.ACTION_UP -> if (tracking) { tracking = false; finish(event.x, event.y) }
      MotionEvent.ACTION_CANCEL -> { tracking = false; cancelHighlight() }
    }
    if (scrollable) super.dispatchTouchEvent(event)
    return true
  }

  private fun local(rawX: Float, rawY: Float): Pair<Float, Float> {
    val location = IntArray(2).also { getLocationOnScreen(it) }
    return (rawX - location[0]) / max(scaleX, 0.01f) to (rawY - location[1]) / max(scaleY, 0.01f)
  }
  internal fun trackExternal(rawX: Float, rawY: Float) {
    if (!isAttachedToWindow) return
    val (x, y) = local(rawX, rawY)
    press(x, y, tick = true)
  }
  internal fun endExternal(rawX: Float, rawY: Float) {
    if (!isAttachedToWindow) return
    val (x, y) = local(rawX, rawY)
    // Lifting off the panel after a long press leaves it open for a normal tap.
    if (rowAt(x, y) == null) { cancelHighlight(); return }
    finish(x, y)
  }
}
