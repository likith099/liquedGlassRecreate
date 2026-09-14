package com.adaptiveglass

import android.content.res.ColorStateList
import android.content.res.Configuration
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ReactAccessibilityDelegate
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.material.navigation.NavigationBarView
import org.json.JSONArray

private data class TabEntry(val id: String, val title: String, val icon: String,
  val androidIcon: String, val badge: String?, val disabled: Boolean, val label: String)
private class TabSelectionEvent(surfaceId: Int, tag: Int, private val tabId: String) : Event<TabSelectionEvent>(surfaceId, tag) {
  override fun getEventName() = "topSelectionChange"
  override fun canCoalesce() = false
  override fun getEventData(): WritableMap = Arguments.createMap().apply { putString("id", tabId) }
}

class ALGTabsView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  var itemsJSON = "[]"
  var selectedValue = ""
  var disabled = false
  var glassTint: Int? = null
  var controlTestID: String? = null
  private var entries = emptyList<TabEntry>()
  private var nativeIds = mutableMapOf<String, Int>()
  private var appliedJSON: String? = null
  private var applying = false
  private var bar = makeBar()
  private var defaultIconTint = bar.itemIconTintList
  private var defaultTextTint = bar.itemTextColor

  init { addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)) }
  private fun makeBar(): BottomNavigationView {
    val themeFlag = TypedValue()
    val themed = if (context.theme.resolveAttribute(com.google.android.material.R.attr.isMaterialTheme, themeFlag, true) && themeFlag.data != 0) context
      else ContextThemeWrapper(context, com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar)
    return BottomNavigationView(themed).apply {
      labelVisibilityMode = NavigationBarView.LABEL_VISIBILITY_LABELED
      isItemHorizontalTranslationEnabled = false
      // The React screen owns safe-area padding, including the bottom system inset.
      ViewCompat.setOnApplyWindowInsetsListener(this) { _, insets -> insets }
      setOnItemSelectedListener { item ->
        if (applying) true else emitSelection(item)
      }
      setOnItemReselectedListener { item -> if (!applying) emitSelection(item) }
    }
  }
  private fun emitSelection(item: MenuItem): Boolean {
    if (disabled || !isAttachedToWindow || bar.menu.findItem(item.itemId) !== item) return false
    val entry = entries.firstOrNull { nativeIds[it.id] == item.itemId && !it.disabled } ?: return false
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(
      TabSelectionEvent(UIManagerHelper.getSurfaceId(reactContext), id, entry.id))
    return true // Material owns the provisional native indicator animation.
  }
  fun applyConfiguration() {
    applying = true
    try {
      if (appliedJSON != itemsJSON) {
        appliedJSON = itemsJSON
        val previousOrder = entries.map { it.id }
        entries = try {
          val array = JSONArray(itemsJSON)
          require(array.length() <= 5)
          (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            TabEntry(item.getString("id"), item.getString("title"), item.optString("icon"), item.optString("androidIcon"),
              if (item.has("badge")) item.get("badge").toString() else null,
              item.optBoolean("disabled"), item.optString("accessibilityLabel", item.getString("title")))
          }
        } catch (_: Exception) { emptyList() }
        val retained = entries.associate { it.id to (nativeIds[it.id] ?: View.generateViewId()) }.toMutableMap()
        for ((key, nativeId) in nativeIds) if (!retained.containsKey(key)) bar.removeBadge(nativeId)
        nativeIds = retained
        val rebuild = previousOrder != entries.map { it.id } || bar.menu.size() != entries.size
        if (rebuild) bar.menu.clear()
        entries.forEachIndexed { index, entry ->
          val nativeId = nativeIds.getValue(entry.id)
          val item = if (rebuild) bar.menu.add(Menu.NONE, nativeId, index, entry.title) else bar.menu.findItem(nativeId)
          item.apply {
            title = entry.title
            val custom = if (entry.androidIcon.isEmpty()) 0 else resources.getIdentifier(entry.androidIcon, "drawable", context.packageName)
            setIcon(if (custom != 0) custom else when (entry.icon) {
              "home" -> R.drawable.alg_tab_home
              "search" -> R.drawable.alg_tab_search
              "library" -> R.drawable.alg_tab_library
              "favorites" -> R.drawable.alg_tab_favorites
              "inbox" -> R.drawable.alg_tab_inbox
              "settings" -> R.drawable.alg_tab_settings
              else -> R.drawable.alg_tab_circle
            })
            if (android.os.Build.VERSION.SDK_INT >= 26) contentDescription = entry.label
          }
          if (entry.badge == null) bar.removeBadge(nativeId)
          else bar.getOrCreateBadge(nativeId).apply {
            isVisible = true
            maxCharacterCount = 4
            if (entry.badge == "dot") clearNumber() else number = entry.badge.toIntOrNull() ?: 0
          }
        }
      }
      for (entry in entries) {
        val item = bar.menu.findItem(nativeIds.getValue(entry.id)) ?: continue
        item.isEnabled = !disabled && !entry.disabled
        if (entry.id == selectedValue) item.isChecked = true
      }
      bar.visibility = if (entries.isEmpty()) View.INVISIBLE else View.VISIBLE
      bar.setTag(com.facebook.react.R.id.react_test_id, controlTestID)
      ReactAccessibilityDelegate.setDelegate(bar, bar.isFocusable, bar.importantForAccessibility)
      fun tint(default: ColorStateList?): ColorStateList? {
        val accent = glassTint ?: return default
        return ColorStateList(arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf(android.R.attr.state_checked), intArrayOf()),
          intArrayOf(default?.getColorForState(intArrayOf(-android.R.attr.state_enabled), accent) ?: accent,
            accent, default?.defaultColor ?: accent))
      }
      bar.itemIconTintList = tint(defaultIconTint)
      bar.itemTextColor = tint(defaultTextTint)
      requestLayout()
      post {
        if (isAttachedToWindow) {
          forceLayout(); bar.forceLayout()
          measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY))
          layout(left, top, right, bottom)
        }
      }
    } finally { applying = false }
  }
  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    // Re-resolve Material day/night and text resources without changing route IDs.
    removeView(bar); bar = makeBar()
    defaultIconTint = bar.itemIconTintList; defaultTextTint = bar.itemTextColor
    addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    appliedJSON = null; applyConfiguration()
  }
}
