package com.adaptiveglass

import android.content.res.ColorStateList
import android.graphics.Color
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.PopupMenu
import android.widget.Toolbar
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ReactAccessibilityDelegate
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray

private data class MenuEntry(val id: String, val title: String, val kind: String,
  val disabled: Boolean, val destructive: Boolean, val checked: Boolean?,
  val items: List<MenuEntry>, val placement: String) {
  val isGroup get() = kind == "section" || kind == "submenu"
}
private class MenuActionEvent(surfaceId: Int, tag: Int, private val itemId: String) : Event<MenuActionEvent>(surfaceId, tag) {
  override fun getEventName() = "topMenuAction"
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap().apply { putString("id", itemId) }
}

class ALGMenuView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  private val button = Button(reactContext)
  private val bar = Toolbar(reactContext)
  private val defaultTextColors = button.textColors
  var title = ""
  var itemsJSON = "[]"
  var disabled = false
  var toolbar = false
  var maxVisibleItems = 3
  var glassTint: Int? = null
  var controlLabel: String? = null
  var controlHint: String? = null
  var controlTestID: String? = null
  private var appliedConfiguration: List<Any?>? = null
  private var appliedJSON: String? = null
  private var entries = emptyList<MenuEntry>()
  private var revision = 0
  private var popup: PopupMenu? = null
  private var nextItemId = 1
  private var lastBarWidth = -1

  init {
    button.isAllCaps = false
    button.maxLines = 1
    button.ellipsize = android.text.TextUtils.TruncateAt.END
    addView(button, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    bar.visibility = View.GONE
    button.setOnClickListener { showMenu() }
  }
  private fun decode(array: JSONArray): List<MenuEntry> = (0 until array.length()).map { index ->
    val item = array.getJSONObject(index)
    MenuEntry(item.getString("id"), item.getString("title"), item.optString("kind", "action"),
      item.optBoolean("disabled"), item.optBoolean("destructive"),
      if (item.has("checked")) item.getBoolean("checked") else null,
      item.optJSONArray("items")?.let { decode(it) } ?: emptyList(), item.optString("placement", "automatic"))
  }
  fun applyConfiguration() {
    val configuration = listOf(itemsJSON, disabled, toolbar, maxVisibleItems, glassTint, controlTestID)
    val changed = configuration != appliedConfiguration
    if (appliedJSON != itemsJSON) {
      appliedJSON = itemsJSON
      entries = try { decode(JSONArray(itemsJSON)) } catch (_: Exception) { emptyList() }
    }
    if (changed) { revision += 1; dismissMenus(); appliedConfiguration = configuration }
    button.visibility = if (toolbar) View.GONE else View.VISIBLE
    bar.visibility = if (toolbar) View.VISIBLE else View.GONE
    button.text = title
    button.isEnabled = !disabled && entries.isNotEmpty()
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
  private fun showMenu() {
    if (disabled || entries.isEmpty() || !isAttachedToWindow) return
    dismissMenus()
    val menu = PopupMenu(reactContext, button)
    fill(menu.menu, entries, revision)
    menu.setOnDismissListener { if (popup === menu) popup = null }
    popup = menu
    menu.show()
  }
  private fun dismissMenus() { popup?.dismiss(); bar.dismissPopupMenus() }
  override fun onDetachedFromWindow() { dismissMenus(); super.onDetachedFromWindow() }
}
