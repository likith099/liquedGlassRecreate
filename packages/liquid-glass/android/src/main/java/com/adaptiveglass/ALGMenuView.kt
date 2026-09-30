package com.adaptiveglass

import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.GestureDetector
import android.view.HapticFeedbackConstants
import android.view.Menu
import android.view.MenuItem
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.Toolbar
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ReactAccessibilityDelegate
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.NativeGestureUtil
import com.facebook.react.views.view.ReactViewGroup
import org.json.JSONArray

internal data class MenuEntry(val id: String, val title: String, val kind: String,
  val disabled: Boolean, val destructive: Boolean, val checked: Boolean?,
  val items: List<MenuEntry>, val placement: String, val androidIcon: String = "") {
  val isGroup get() = kind == "section" || kind == "submenu"
}
private class MenuActionEvent(surfaceId: Int, tag: Int, private val itemId: String) : Event<MenuActionEvent>(surfaceId, tag) {
  override fun getEventName() = "topMenuAction"
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap().apply { putString("id", itemId) }
}

/** Payload-free lifecycle events: topButtonPress, topMenuOpen, topMenuClose. */
private class MenuLifecycleEvent(surfaceId: Int, tag: Int, private val name: String) : Event<MenuLifecycleEvent>(surfaceId, tag) {
  override fun getEventName() = name
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap()
}

class ALGMenuView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  val reactContent = ReactViewGroup(reactContext)
  var contextMenu = false
  private val button = Button(reactContext)
  private val bar = Toolbar(reactContext)
  private val icon = ImageView(reactContext)
  private val defaultTextColors = button.textColors
  private val defaultBackground = button.background
  var title = ""
  var itemsJSON = "[]"
  var disabled = false
  var toolbar = false
  var maxVisibleItems = 3
  var glassTint: Int? = null
  var controlLabel: String? = null
  var controlHint: String? = null
  var controlTestID: String? = null
  var iconMode = false
  var colorScheme = "system"
  var androidIcon = ""
  var iconProminent = false
  /** Context menu: "below" keeps the popup below the content, lifting the content if needed. */
  var menuPlacement = "system"
  /** How far the content is lifted for the open popup, in pixels. */
  private var lifted = 0f
  /** An invisible anchor for GlassMenuPanel: open() shows the popup attached to this view's frame. */
  var menuAnchor = false
  /** Corner radius and light/dark colours of the menu popup, as JSON; empty for the defaults. */
  var menuStyleJSON = ""
  /** Icon mode without items is a plain button. */
  private val isPlainButton get() = iconMode && entries.isEmpty()
  private var appliedConfiguration: List<Any?>? = null
  private var appliedJSON: String? = null
  private var entries = emptyList<MenuEntry>()
  private var revision = 0
  private var popup: ALGMenuPopup? = null
  private var nextItemId = 1
  private var lastBarWidth = -1
  /**
   * Context menus open on a long press anywhere over the React content. React Native's views claim
   * every touch they receive, so a long-click listener on this view never fires for touches on the
   * content; the gesture is observed in dispatchTouchEvent instead, without taking it from the content.
   */
  private val longPress = GestureDetector(reactContext, object : GestureDetector.SimpleOnGestureListener() {
    override fun onLongPress(event: MotionEvent) {
      if (!contextMenu || disabled || entries.isEmpty()) return
      performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
      // The native gesture now owns the touch: JavaScript responders are cancelled, so a pressable
      // inside the content does not also fire when the finger lifts.
      NativeGestureUtil.notifyNativeGestureStarted(this@ALGMenuView, event)
      showMenu()
    }
  }).apply { setIsLongpressEnabled(true) }

  init {
    button.isAllCaps = false
    button.maxLines = 1
    button.ellipsize = android.text.TextUtils.TruncateAt.END
    addView(button, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    // The glyph sits over the button; the button keeps the touch, ripple and accessibility.
    icon.isClickable = false
    icon.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    icon.visibility = View.GONE
    addView(icon, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.CENTER))
    addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    addView(reactContent, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    reactContent.visibility = View.GONE
    // Accessibility long-press actions (TalkBack) arrive here rather than as touches.
    setOnLongClickListener {
      if (contextMenu && !disabled && entries.isNotEmpty()) { if (popup == null) showMenu(); true } else false
    }
    bar.visibility = View.GONE
    button.setOnClickListener {
      if (isPlainButton) { if (!disabled && isAttachedToWindow) dispatchLifecycle("topButtonPress") } else showMenu()
    }
  }
  private fun decode(array: JSONArray): List<MenuEntry> = (0 until array.length()).map { index ->
    val item = array.getJSONObject(index)
    MenuEntry(item.getString("id"), item.getString("title"), item.optString("kind", "action"),
      item.optBoolean("disabled"), item.optBoolean("destructive"),
      if (item.has("checked")) item.getBoolean("checked") else null,
      item.optJSONArray("items")?.let { decode(it) } ?: emptyList(), item.optString("placement", "automatic"),
      item.optString("androidIcon"))
  }
  fun applyConfiguration() {
    val configuration = listOf(itemsJSON, disabled, toolbar, maxVisibleItems, glassTint, controlTestID, contextMenu,
      iconMode, colorScheme, androidIcon, iconProminent, menuStyleJSON, menuAnchor)
    val changed = configuration != appliedConfiguration
    if (appliedJSON != itemsJSON) {
      appliedJSON = itemsJSON
      entries = try { decode(JSONArray(itemsJSON)) } catch (_: Exception) { emptyList() }
    }
    if (changed) { revision += 1; dismissMenus(); appliedConfiguration = configuration }
    // An anchor keeps its button laid out but unseen; only the popup it opens is shown.
    button.visibility = if (toolbar || contextMenu) View.GONE else if (menuAnchor) View.INVISIBLE else View.VISIBLE
    button.importantForAccessibility = if (menuAnchor) View.IMPORTANT_FOR_ACCESSIBILITY_NO else View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
    bar.visibility = if (toolbar && !contextMenu) View.VISIBLE else View.GONE
    reactContent.visibility = if (contextMenu) View.VISIBLE else View.GONE
    isLongClickable = contextMenu && !disabled && entries.isNotEmpty()
    if (contextMenu) {
      contentDescription = controlLabel
      setTag(com.facebook.react.R.id.react_test_id, controlTestID)
      ReactAccessibilityDelegate.setDelegate(this, isFocusable, importantForAccessibility)
    }
    button.text = if (iconMode) "" else title
    button.isEnabled = !disabled && (isPlainButton || entries.isNotEmpty())
    applyIconAppearance()
    button.contentDescription = controlLabel?.takeIf { it.isNotEmpty() } ?: title
    if (android.os.Build.VERSION.SDK_INT >= 26) button.tooltipText = controlHint
    button.setTag(com.facebook.react.R.id.react_test_id, controlTestID)
    ReactAccessibilityDelegate.setDelegate(button, button.isFocusable, button.importantForAccessibility)
    bar.setTag(com.facebook.react.R.id.react_test_id, controlTestID)
    ReactAccessibilityDelegate.setDelegate(bar, bar.isFocusable, bar.importantForAccessibility)
    button.setTextColor(glassTint?.let { ColorStateList.valueOf(it) } ?: defaultTextColors)
    if (toolbar && changed && width > 0) {
      updateToolbar()
    }
  }
  /** An oval surface with a ripple and a centered drawable, or the standard button. */
  private fun applyIconAppearance() {
    icon.visibility = if (iconMode && !toolbar && !contextMenu) View.VISIBLE else View.GONE
    if (!iconMode) {
      button.background = defaultBackground
      return
    }
    val dark = isDark()
    val fill = GradientDrawable().apply {
      shape = GradientDrawable.OVAL
      setColor(if (iconProminent) glassTint ?: Color.parseColor("#6159B7")
        else if (dark) Color.parseColor("#25272D") else Color.parseColor("#F0F1F5"))
    }
    val mask = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.WHITE) }
    button.background = RippleDrawable(ColorStateList.valueOf(Color.parseColor("#40808080")), fill, mask)
    button.minWidth = 0
    button.minimumWidth = 0
    button.minHeight = 0
    button.minimumHeight = 0
    button.stateListAnimator = null
    val resource = if (androidIcon.isEmpty()) 0 else resources.getIdentifier(androidIcon, "drawable", context.packageName)
    icon.setImageResource(resource)
    val foreground = if (iconProminent) Color.WHITE else glassTint ?: if (dark) Color.WHITE else Color.parseColor("#1C1C1E")
    icon.imageTintList = ColorStateList.valueOf(foreground)
    icon.alpha = if (button.isEnabled) 1f else 0.4f
  }
  /** Presents the menu as if tapped; the command from ref.open(). */
  fun openMenu() {
    if (toolbar || contextMenu || isPlainButton || !button.isEnabled) return
    showMenu()
  }
  private fun dispatchLifecycle(name: String) {
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
      MenuLifecycleEvent(UIManagerHelper.getSurfaceId(reactContext), id, name))
  }
  private fun updateToolbar() {
    bar.dismissPopupMenus()
    bar.menu.clear()
    fill(bar.menu, entries, revision, toolbarRoot = true)
    // Fabric owns this host's frame, so explicitly remeasure the native children.
    requestLayout()
    // A request made inside onLayout can be cleared as that layout finishes.
    // Force the posted measurement so newly added native actions receive bounds.
    post { if (isAttachedToWindow) { forceLayout(); bar.forceLayout(); measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)); layout(left, top, right, bottom) } }
  }
  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    super.onLayout(changed, left, top, right, bottom)
    // onSizeChanged may run before the frame's width getter reflects Fabric's
    // final bounds. Budget actions only after layout has established those bounds.
    if (toolbar && lastBarWidth != width) {
      lastBarWidth = width
      updateToolbar()
    }
  }
  private fun enabledAction(id: String, nodes: List<MenuEntry>): MenuEntry? {
    for (entry in nodes) {
      if (entry.disabled) continue
      if (entry.isGroup) { enabledAction(id, entry.items)?.let { return it } }
      else if (entry.id == id) return entry
    }
    return null
  }
  private fun label(entry: MenuEntry): CharSequence {
    val color = if (entry.destructive) TypedValue().let { value ->
      if (android.os.Build.VERSION.SDK_INT >= 26 && context.theme.resolveAttribute(android.R.attr.colorError, value, true)) {
        if (value.resourceId != 0) context.getColor(value.resourceId) else value.data
      } else Color.rgb(180, 32, 32)
    } else glassTint
    return if (color != null && !entry.disabled) SpannableString(entry.title).apply {
      setSpan(ForegroundColorSpan(color), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    } else entry.title
  }
  private fun fill(menu: Menu, nodes: List<MenuEntry>, version: Int, toolbarRoot: Boolean = false, group: Int = 0) {
    var visibleCount = 0
    val density = resources.displayMetrics.density
    // Toolbar's presenter budgets against the screen, not necessarily a narrow
    // embedded Fabric view. Bound its action candidates to this host's width.
    var available = width - 32 * density - (if (nodes.size > 1) 56 * density else 0f)
    for (entry in nodes) {
      val nativeId = nextItemId++
      if (entry.kind == "section") {
        if (entry.title.isNotEmpty()) menu.add(nativeId, nativeId, Menu.NONE, entry.title).isEnabled = false
        fill(menu, entry.items, version, group = nativeId)
        continue
      }
      val item: MenuItem = if (entry.kind == "submenu") {
        val submenu = menu.addSubMenu(group, nativeId, Menu.NONE, label(entry))
        fill(submenu, entry.items, version)
        submenu.item
      } else menu.add(group, nativeId, Menu.NONE, label(entry))
      item.isEnabled = !disabled && !entry.disabled
      item.isCheckable = !entry.isGroup && entry.checked != null
      item.isChecked = entry.checked == true
      if (android.os.Build.VERSION.SDK_INT >= 26) item.contentDescription = entry.title
      if (toolbarRoot) {
        val required = maxOf(56 * density, button.paint.measureText(entry.title.uppercase()) + 32 * density)
        val canShow = entry.placement != "overflow" && visibleCount < maxVisibleItems && required <= available
        // This host has already reserved space for overflow. IF_ROOM can use a
        // stale presenter budget while Fabric lays out an embedded toolbar.
        item.setShowAsAction(if (canShow) MenuItem.SHOW_AS_ACTION_ALWAYS or MenuItem.SHOW_AS_ACTION_WITH_TEXT else MenuItem.SHOW_AS_ACTION_NEVER)
        if (canShow) { visibleCount += 1; available -= required }
      }
      if (!entry.isGroup) item.setOnMenuItemClickListener {
        if (!disabled && version == revision && isAttachedToWindow && enabledAction(entry.id, entries) != null) {
          UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
            MenuActionEvent(UIManagerHelper.getSurfaceId(reactContext), id, entry.id))
        }
        true
      }
    }
    if (android.os.Build.VERSION.SDK_INT >= 28) menu.setGroupDividerEnabled(true)
  }
  private fun isDark() = when (colorScheme) {
    "dark" -> true
    "light" -> false
    else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
  }
  private fun showMenu() {
    if (disabled || entries.isEmpty() || !isAttachedToWindow) return
    dismissMenus()
    val version = revision
    lateinit var menu: ALGMenuPopup
    // Long-press menus get a wider floor (208 dp) so short action lists are not narrow beside the
    // content, closer to the system menu's width on iOS; menu buttons keep Material's 112 dp.
    menu = ALGMenuPopup(context, entries, MenuStyle.from(menuStyleJSON, isDark()), allDisabled = disabled, tint = glassTint,
      minWidthDp = if (contextMenu) 208f else 112f,
      onSelect = { entry ->
        if (!disabled && version == revision && isAttachedToWindow && enabledAction(entry.id, entries) != null) {
          UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
            MenuActionEvent(UIManagerHelper.getSurfaceId(reactContext), id, entry.id))
        }
      },
      onDismiss = {
        if (popup === menu) popup = null
        lower()
        dispatchLifecycle("topMenuClose")
      })
    popup = menu
    when {
      menuAnchor -> menu.showOver(this)
      contextMenu && menuPlacement == "below" -> liftThenShow(menu)
      else -> menu.showAt(if (contextMenu) this else button)
    }
    dispatchLifecycle("topMenuOpen")
  }
  /**
   * The popup always opens below the content: when it would not fit, the content glides up just
   * enough first (the counterpart of iOS lifting its preview), and glides back when the popup closes.
   */
  private fun liftThenShow(menu: ALGMenuPopup) {
    val density = resources.displayMetrics.density
    val location = IntArray(2).also { getLocationOnScreen(it) }
    val visible = android.graphics.Rect().also { getWindowVisibleDisplayFrame(it) }
    val bottom = location[1] + height
    val overflow = bottom + menu.heightBelowAnchor() - (visible.bottom - 8 * density)
    val room = location[1] - (visible.top + 8 * density)
    val shift = if (overflow > 0) minOf(overflow, maxOf(0f, room)) else 0f
    if (shift <= 0f) { menu.showAt(this); return }
    lifted = shift
    animate().translationY(-shift).setDuration(180).setInterpolator(android.view.animation.DecelerateInterpolator())
      .withEndAction { if (popup === menu && isAttachedToWindow) menu.showAt(this) }.start()
  }
  private fun lower() {
    if (lifted == 0f) return
    lifted = 0f
    animate().translationY(0f).setDuration(150).setInterpolator(android.view.animation.DecelerateInterpolator()).start()
  }
  override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    if (contextMenu) longPress.onTouchEvent(event)
    return super.dispatchTouchEvent(event)
  }
  private fun dismissMenus() { popup?.dismiss(); bar.dismissPopupMenus() }
  override fun onDetachedFromWindow() { dismissMenus(); super.onDetachedFromWindow() }
}
