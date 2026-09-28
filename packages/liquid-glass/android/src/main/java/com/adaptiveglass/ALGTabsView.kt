package com.adaptiveglass

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.StateListDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.LruCache
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
import com.google.android.material.navigation.NavigationBarItemView
import com.google.android.material.navigation.NavigationBarView
import java.net.URL
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

private data class TabEntry(val id: String, val title: String, val icon: String,
  val androidIcon: String, val badge: String?, val disabled: Boolean, val label: String,
  /** Resolved image source URIs: a Metro URL in development, a drawable name in release, or any URI. */
  val imageUri: String?, val selectedImageUri: String?, val original: Boolean,
  val selectedTint: Int?, val inactiveTint: Int?) {
  val tinted get() = selectedTint != null || inactiveTint != null
}
private fun JSONObject.color(key: String): Int? = if (has(key)) getDouble(key).toLong().toInt() else null
private fun JSONObject.sourceUri(key: String): String? = optJSONObject(key)?.optString("uri")?.takeIf { it.isNotEmpty() }

/** Artwork from image sources, decoded once per URI and held in memory only. Callbacks run on the main thread. */
private object TabImageLoader {
  private val cache = object : LruCache<String, Bitmap>(8 * 1024 * 1024) {
    override fun sizeOf(key: String, value: Bitmap) = value.byteCount
  }
  private val waiting = mutableMapOf<String, MutableList<() -> Unit>>()
  private val failed = mutableSetOf<String>()
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())
  fun cached(uri: String): Bitmap? = cache.get(uri)
  fun hasFailed(uri: String) = uri in failed
  fun load(context: Context, uri: String, completion: () -> Unit) {
    waiting[uri]?.let { it.add(completion); return }
    waiting[uri] = mutableListOf(completion)
    val resolver = context.applicationContext.contentResolver
    worker.execute {
      val bitmap = try {
        val parsed = Uri.parse(uri)
        when (parsed.scheme) {
          "http", "https" -> URL(uri).openStream().use(BitmapFactory::decodeStream)
          "file" -> BitmapFactory.decodeFile(parsed.path)
          "data" -> Base64.decode(uri.substringAfter(','), Base64.DEFAULT).let { BitmapFactory.decodeByteArray(it, 0, it.size) }
          else -> resolver.openInputStream(parsed)?.use(BitmapFactory::decodeStream)
        }
      } catch (_: Exception) { null }
      main.post {
        if (bitmap != null) cache.put(uri, bitmap) else failed.add(uri)
        waiting.remove(uri)?.forEach { it() }
      }
    }
  }
}
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
  var barBackgroundColor: Int? = null
  var barIndicatorColor: Int? = null
  var controlTestID: String? = null
  private var entries = emptyList<TabEntry>()
  private var nativeIds = mutableMapOf<String, Int>()
  private var appliedJSON: String? = null
  private var applying = false
  private var bar = makeBar()
  private var defaultIconTint = bar.itemIconTintList
  private var defaultTextTint = bar.itemTextColor
  private var defaultBackground = bar.background
  private var defaultIndicatorColor = bar.itemActiveIndicatorColor

  init { addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)) }
  private fun makeBar(): BottomNavigationView {
    val themeFlag = TypedValue()
    val themed = if (context.theme.resolveAttribute(com.google.android.material.R.attr.isMaterialTheme, themeFlag, true) && themeFlag.data != 0) context
      else ContextThemeWrapper(context, com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar)
    return BottomNavigationView(themed).apply {
      labelVisibilityMode = NavigationBarView.LABEL_VISIBILITY_LABELED
      // Labels scale with the system text size.
      setLabelFontScalingEnabled(true)
      setLabelMaxLines(2)
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
              item.optBoolean("disabled"), item.optString("accessibilityLabel", item.getString("title")),
              item.sourceUri("imageSource"), item.sourceUri("selectedImageSource"),
              item.optString("imageRenderingMode") == "original", item.color("selectedTint"), item.color("inactiveTint"))
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
            setIcon(iconFor(entry))
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
      applyItemColors()
      bar.background = barBackgroundColor?.let(::ColorDrawable) ?: defaultBackground
      bar.itemActiveIndicatorColor = barIndicatorColor?.let(ColorStateList::valueOf) ?: defaultIndicatorColor
      requestLayout()
      post {
        if (isAttachedToWindow) {
          forceNativeLayout()
          // Material derives each active indicator's layout params from its item view's width
          // at the moment the item is checked. The first selection happens while the bar is
          // still unmeasured, so that width is 0, the indicator clamps to 0x0 and stays a stub
          // beside the icon until a later tap re-checks the item. Re-assigning the desired
          // width makes every item recompute against its real width. React Native swallows the
          // requestLayout that changing those params triggers, so lay the bar out again.
          bar.itemActiveIndicatorWidth = bar.itemActiveIndicatorWidth
          applyItemColors()
          forceNativeLayout()
        }
      }
    } finally { applying = false }
  }
  /** The item's icon: androidIcon, then its image sources, then the preset. */
  private fun iconFor(entry: TabEntry): Drawable {
    val custom = if (entry.androidIcon.isEmpty()) 0 else resources.getIdentifier(entry.androidIcon, "drawable", context.packageName)
    val normal = if (custom != 0) context.getDrawable(custom) else entry.imageUri?.let(::sourceDrawable)
    val preset = context.getDrawable(when (entry.icon) {
      "home" -> R.drawable.alg_tab_home
      "search" -> R.drawable.alg_tab_search
      "library" -> R.drawable.alg_tab_library
      "favorites" -> R.drawable.alg_tab_favorites
      "inbox" -> R.drawable.alg_tab_inbox
      "settings" -> R.drawable.alg_tab_settings
      else -> R.drawable.alg_tab_circle
    })!!
    val base = normal ?: preset
    val selected = entry.selectedImageUri?.let(::sourceDrawable) ?: return base
    // The item view passes its checked state to the icon, so a state list swaps the artwork.
    return StateListDrawable().apply {
      addState(intArrayOf(android.R.attr.state_checked), selected)
      addState(intArrayOf(), base)
    }
  }
  /**
   * A drawable for an image source. A name without a scheme is a drawable resource, which is how
   * release builds package require() images. Other URIs load once in the background: a clear
   * placeholder shows meanwhile and the menu is rebuilt when the bitmap arrives. A failed source
   * gives null, so the item falls back to its preset.
   */
  private fun sourceDrawable(uri: String): Drawable? {
    if (Uri.parse(uri).scheme == null) {
      val resource = resources.getIdentifier(uri, "drawable", context.packageName)
      return if (resource != 0) context.getDrawable(resource) else null
    }
    TabImageLoader.cached(uri)?.let { return BitmapDrawable(resources, it) }
    if (TabImageLoader.hasFailed(uri)) return null
    TabImageLoader.load(context, uri) {
      if (isAttachedToWindow || parent != null) { appliedJSON = null; applyConfiguration() }
    }
    return ColorDrawable(Color.TRANSPARENT)
  }
  /** A tab's own colours over the bar's list: disabled keeps the bar's, checked and default take the tab's. */
  private fun itemTint(entry: TabEntry, base: ColorStateList?): ColorStateList {
    val disabledState = intArrayOf(-android.R.attr.state_enabled)
    val checkedState = intArrayOf(android.R.attr.state_checked, android.R.attr.state_enabled)
    val fallback = base?.defaultColor ?: Color.GRAY
    return ColorStateList(arrayOf(disabledState, intArrayOf(android.R.attr.state_checked), intArrayOf()), intArrayOf(
      base?.getColorForState(disabledState, fallback) ?: fallback,
      entry.selectedTint ?: base?.getColorForState(checkedState, fallback) ?: fallback,
      entry.inactiveTint ?: fallback))
  }
  /**
   * Per-tab colours and original-colour artwork, applied to each item view after the bar-wide
   * lists, which Material copies to every item. Item views carry their menu item's id.
   */
  private fun applyItemColors() {
    for (entry in entries) {
      val itemView = bar.findViewById<View>(nativeIds[entry.id] ?: continue) as? NavigationBarItemView ?: continue
      if (entry.original) itemView.setIconTintList(null)
      else if (entry.tinted) itemView.setIconTintList(itemTint(entry, bar.itemIconTintList))
      if (entry.tinted) itemView.setTextColor(itemTint(entry, bar.itemTextColor))
    }
  }
  private fun forceNativeLayout() {
    forceLayout(); bar.forceLayout()
    measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY))
    layout(left, top, right, bottom)
  }
  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    // Re-resolve Material day/night and text resources without changing route IDs.
    removeView(bar); bar = makeBar()
    defaultIconTint = bar.itemIconTintList; defaultTextTint = bar.itemTextColor
    defaultBackground = bar.background; defaultIndicatorColor = bar.itemActiveIndicatorColor
    addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    appliedJSON = null; applyConfiguration()
  }
}
