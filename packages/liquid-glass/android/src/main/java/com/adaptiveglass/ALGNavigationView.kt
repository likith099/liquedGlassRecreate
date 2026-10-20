package com.adaptiveglass

import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.text.Editable
import android.text.TextWatcher
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.widget.PopupMenu
import androidx.coordinatorlayout.widget.CoordinatorLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.google.android.material.appbar.AppBarLayout
import com.google.android.material.appbar.CollapsingToolbarLayout
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.search.SearchBar
import com.google.android.material.search.SearchView
import com.google.android.material.tabs.TabLayout
import org.json.JSONArray
import org.json.JSONObject

private class NavigationEvent(surface: Int, tag: Int, private val name: String, private val data: WritableMap) : Event<NavigationEvent>(surface, tag) {
  override fun getEventName() = name
  override fun canCoalesce() = false
  override fun getEventData() = data
}
/** Material owns toolbar layout/overflow, nested-scroll collapse and the search transition. */
class ALGNavigationView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  val reactChildren = mutableListOf<View>()
  var scrollTag = -1
  private val themed = ContextThemeWrapper(reactContext, com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar)
  private val coordinator = CoordinatorLayout(themed)
  private val appBar = AppBarLayout(themed)
  private val collapse = CollapsingToolbarLayout(themed)
  private val toolbar = MaterialToolbar(themed)
  private val bottomBar = LinearLayout(themed).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
  private val content = FrameLayout(themed)
  private val titleSlot = FrameLayout(themed)
  private val subtitleSlot = FrameLayout(themed)
  private val largeSubtitleSlot = FrameLayout(themed)
  private val accessory = FrameLayout(themed)
  private val searchBar = SearchBar(themed)
  private val searchView = SearchView(themed)
  private val scopes = TabLayout(themed)
  private val searchResults = LinearLayout(themed).apply { orientation = LinearLayout.VERTICAL }
  private val searchBody = FrameLayout(themed)
  private var config = JSONObject()
  private var actionJSON = ""
  private var searchEventCount = 0
  private var applying = false
  private var programmaticDismiss = false
  private var searchOpen = false
  private var systemInsets = androidx.core.graphics.Insets.NONE
  private var lastInsets = ""
  private var lastScopes = ""
  private var bottomHeight = 0
  private val actionIDs = mutableMapOf<Int, JSONObject>()
  private val menuNumbers = mutableMapOf<String, Int>()
  private var nextMenuNumber = 100
  private val leadingViews = mutableListOf<View>()
  private val headerSize = 56
  private var relayoutPending = false
  private fun dp(value: Double) = (value * resources.displayMetrics.density).toInt()
  private fun px(value: Int) = value / resources.displayMetrics.density.toDouble()
  private fun emit(name: String, data: WritableMap) {
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(NavigationEvent(UIManagerHelper.getSurfaceId(this), id, name, data))
  }
  private fun testID(view: View, id: String) {
    view.setTag(com.facebook.react.R.id.react_test_id, id)
    com.facebook.react.uimanager.ReactAccessibilityDelegate.setDelegate(view, view.isFocusable, view.importantForAccessibility)
  }
  private fun action(id: String, item: String = "") { emit("topNavigationAction", Arguments.createMap().apply { putString("id", id); putString("action", item) }) }
  private fun search(kind: String, text: String = searchView.text.toString()) {
    emit("topNavigationSearch", Arguments.createMap().apply { putString("kind", kind); putString("text", text); putInt("eventCount", searchEventCount) })
  }
  init {
    clipChildren = true
    addView(coordinator); addView(bottomBar); addView(searchView, LayoutParams(-1, -1))
    coordinator.addView(content, CoordinatorLayout.LayoutParams(-1, -1).apply { behavior = AppBarLayout.ScrollingViewBehavior() })
    coordinator.addView(appBar, CoordinatorLayout.LayoutParams(-1, -2))
    appBar.addView(collapse, AppBarLayout.LayoutParams(-1, dp(56.0)))
    collapse.addView(toolbar, CollapsingToolbarLayout.LayoutParams(-1, dp(56.0)).apply { collapseMode = CollapsingToolbarLayout.LayoutParams.COLLAPSE_MODE_PIN })
    toolbar.addView(titleSlot, androidx.appcompat.widget.Toolbar.LayoutParams(-1, -1).apply { gravity = Gravity.CENTER_VERTICAL })
    appBar.addView(subtitleSlot, AppBarLayout.LayoutParams(-1, 0))
    appBar.addView(largeSubtitleSlot, AppBarLayout.LayoutParams(-1, 0))
    appBar.addView(searchBar, AppBarLayout.LayoutParams(-1, dp(56.0)))
    appBar.addView(accessory, AppBarLayout.LayoutParams(-1, 0))
    appBar.isLiftOnScroll = true
    searchView.setupWithSearchBar(searchBar)
    searchResults.addView(scopes, LinearLayout.LayoutParams(-1, -2))
    searchResults.addView(searchBody, LinearLayout.LayoutParams(-1, 0, 1f))
    searchView.addView(searchResults, ViewGroup.LayoutParams(-1, -1))
    searchBar.setOnClickListener { focusSearch() }
    searchView.addTransitionListener { _, _, state ->
      if (state == SearchView.TransitionState.SHOWING) {
        searchOpen = true; moveBody(true); search("focus")
      } else if (state == SearchView.TransitionState.HIDDEN && searchOpen) {
        searchOpen = false; moveBody(false)
        if (!programmaticDismiss) { searchView.editText.setText(""); search("cancel", "") }
        programmaticDismiss = false; search("blur"); requestLayout()
      }
    }
    searchView.editText.addTextChangedListener(object : TextWatcher {
      override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
      override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
        if (!applying) { searchEventCount++; searchBar.setText(s); search("change", s?.toString() ?: "") }
      }
      override fun afterTextChanged(s: Editable?) = Unit
    })
    searchView.editText.setOnEditorActionListener { _, _, _ -> search("submit"); true }
    scopes.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
      override fun onTabSelected(tab: TabLayout.Tab) { if (!applying) search("scope", tab.tag as? String ?: "") }
      override fun onTabUnselected(tab: TabLayout.Tab) = Unit
      override fun onTabReselected(tab: TabLayout.Tab) = Unit
    })
    ViewCompat.setOnApplyWindowInsetsListener(this) { _, insets ->
      systemInsets = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()); requestLayout(); insets
    }
    appBar.addOnOffsetChangedListener(AppBarLayout.OnOffsetChangedListener { _, _ -> reportInsets() })
  }
  override fun onAttachedToWindow() { super.onAttachedToWindow(); ViewCompat.requestApplyInsets(this) }
  override fun requestLayout() {
    super.requestLayout()
    if (!relayoutPending) { relayoutPending = true; post { relayoutPending = false; if (width > 0 && height > 0) { measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)); layout(left, top, right, bottom) } } }
  }
  fun mount(child: View, index: Int) {
    reactChildren.add(index, child)
    val parent = when (index) { 0 -> content; 1 -> titleSlot; 2 -> subtitleSlot; 3 -> largeSubtitleSlot; else -> accessory }
    parent.addView(child, ViewGroup.LayoutParams(-1, -1)); requestLayout()
  }
  fun unmount(index: Int) { val child = reactChildren.removeAt(index); (child.parent as? ViewGroup)?.removeView(child) }
  private fun moveBody(intoSearch: Boolean) {
    val body = reactChildren.firstOrNull() ?: return
    (body.parent as? ViewGroup)?.removeView(body)
    if (intoSearch) searchBody.addView(body, LayoutParams(-1, -1)) else content.addView(body, LayoutParams(-1, -1))
  }
  fun configure(json: String) {
    val next = try { JSONObject(json) } catch (_: Exception) { return }
    config = next; applying = true
    val dark = config.optString("colorScheme") == "dark" || (config.optString("colorScheme") == "system" && resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES)
    val ink = if (dark) Color.WHITE else Color.rgb(24, 32, 45)
    val background = color(config, "background", if (dark) Color.rgb(18,20,26) else Color.rgb(247,248,252))
    val tint = color(config, "tint", ink)
    setBackgroundColor(background); appBar.setBackgroundColor(background); toolbar.setBackgroundColor(background); bottomBar.setBackgroundColor(background)
    toolbar.setTitleTextColor(ink); toolbar.setSubtitleTextColor(ink); toolbar.setNavigationIconTint(tint)
    val slots = config.optJSONArray("slots")
    fun slot(index: Int) = slots?.optJSONObject(index)
    val custom = slot(1)?.optBoolean("present") == true
    val expandable = config.optBoolean("androidCollapsing") && config.optString("titleDisplayMode") != "inline" && !custom
    val fonts = config.optJSONObject("titleFont")
    toolbar.title = if (custom || expandable) "" else config.optString("title")
    toolbar.subtitle = if (custom) null else config.optString("subtitle", "").ifEmpty { null }
    titleSlot.visibility = if (custom) VISIBLE else GONE
    collapse.isTitleEnabled = expandable
    collapse.title = config.optString("title")
    collapse.setCollapsedTitleTextColor(ink); collapse.setExpandedTitleColor(ink)
    collapse.collapsedTitleGravity = Gravity.START or Gravity.CENTER_VERTICAL
    collapse.expandedTitleGravity = Gravity.START or Gravity.BOTTOM
    collapse.setExpandedTitleMargin(dp(20.0), 0, dp(20.0), dp(20.0))
    collapse.setExpandedTitleTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_HeadlineLarge)
    collapse.setCollapsedTitleTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_TitleLarge)
    // Public setters scale with the user's font scale, as standard TextViews do.
    collapse.expandedTitleTextSize = (fonts?.optDouble("largeSize", 34.0) ?: 34.0).toFloat() * resources.displayMetrics.scaledDensity
    collapse.collapsedTitleTextSize = (fonts?.optDouble("compactSize", 17.0) ?: 17.0).toFloat() * resources.displayMetrics.scaledDensity
    collapse.layoutParams = (collapse.layoutParams as AppBarLayout.LayoutParams).apply {
      height = dp(if (expandable) 152.0 else 56.0)
      scrollFlags = if (expandable) AppBarLayout.LayoutParams.SCROLL_FLAG_SCROLL or AppBarLayout.LayoutParams.SCROLL_FLAG_EXIT_UNTIL_COLLAPSED or AppBarLayout.LayoutParams.SCROLL_FLAG_SNAP else 0
    }
    collapse.minimumHeight = dp(56.0)
    for ((index, view) in listOf(2 to subtitleSlot, 3 to largeSubtitleSlot, 4 to accessory)) {
      val height = if (slot(index)?.optBoolean("present") == true) dp(slot(index)?.optDouble("height") ?: 0.0) else 0
      view.layoutParams = (view.layoutParams as AppBarLayout.LayoutParams).apply { this.height = height }
      view.visibility = if (height > 0) VISIBLE else GONE
    }
    val itemsKey = listOf(config.optJSONArray("leading"), config.optJSONArray("trailing"), config.optJSONArray("toolbar"), tint).joinToString()
    if (itemsKey != actionJSON) { actionJSON = itemsKey; updateActions(tint) }
    val searchConfig = config.optJSONObject("search")
    searchBar.visibility = if (searchConfig == null) GONE else VISIBLE
    if (searchConfig != null) {
      val hint = searchConfig.optString("placeholder", resources.getString(android.R.string.search_go))
      searchBar.hint = hint; searchView.hint = hint
      testID(searchBar, searchConfig.optString("testID", "navigation-search") + "-bar")
      testID(searchView.editText, searchConfig.optString("testID", "navigation-search"))
      searchView.toolbar.navigationContentDescription = searchConfig.optString("cancelLabel", "Close search")
      val input = android.text.InputType.TYPE_CLASS_TEXT
      val inputType = input or when (searchConfig.optString("autoCapitalize")) {
        "characters" -> android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS; "words" -> android.text.InputType.TYPE_TEXT_FLAG_CAP_WORDS; "sentences" -> android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES; else -> 0 }
      // setInputType restarts the input connection even for an equal value.
      // Controlled query echoes must not interrupt a burst of keyboard events.
      if (searchView.editText.inputType != inputType) searchView.editText.inputType = inputType
      val imeOptions = when (searchConfig.optString("returnKeyType")) { "done" -> EditorInfo.IME_ACTION_DONE; "go" -> EditorInfo.IME_ACTION_GO; else -> EditorInfo.IME_ACTION_SEARCH }
      if (searchView.editText.imeOptions != imeOptions) searchView.editText.imeOptions = imeOptions
      if (searchConfig.optInt("eventCount") >= searchEventCount && searchView.text.toString() != searchConfig.optString("value")) { searchView.setText(searchConfig.optString("value")); searchBar.setText(searchConfig.optString("value")) }
      val values = searchConfig.optJSONArray("scopes") ?: JSONArray()
      if (values.toString() != lastScopes) {
        lastScopes = values.toString(); scopes.removeAllTabs()
        for (i in 0 until values.length()) { val item = values.getJSONObject(i); scopes.addTab(scopes.newTab().setText(item.getString("title")).setTag(item.getString("id"))) }
      }
      scopes.visibility = if (values.length() == 0) GONE else VISIBLE
      for (i in 0 until scopes.tabCount) if (scopes.getTabAt(i)?.tag == searchConfig.optString("scope")) scopes.selectTab(scopes.getTabAt(i))
      if (searchConfig.has("active") && searchConfig.getBoolean("active") != searchOpen) post {
        // A later config can remove/dismiss search before this UI task runs.
        val latest = config.optJSONObject("search")
        if (latest?.has("active") == true && latest.getBoolean("active") != searchOpen) {
          if (latest.getBoolean("active")) focusSearch() else dismissSearch()
        }
      }
    } else if (searchOpen) dismissSearch()
    applying = false
    post {
      for (i in 0 until toolbar.childCount) {
        val child = toolbar.getChildAt(i)
        if (child is TextView) { child.maxLines = 1; if (child.text == toolbar.title) { child.textSize = (fonts?.optDouble("compactSize", 17.0) ?: 17.0).toFloat(); testID(child, config.optString("titleTestID", "")) } }
      }
      reportInsets()
    }
    requestLayout()
  }
  private fun color(entry: JSONObject, name: String, fallback: Int): Int = if (entry.has(name) && !entry.isNull(name)) entry.getDouble(name).toLong().toInt() else fallback
  private fun drawable(entry: JSONObject, tint: Int): Drawable? {
    val uri = entry.optJSONObject("imageSource")?.optString("uri")
    if (!uri.isNullOrEmpty()) {
      val bitmap = TabImageLoader.cached(uri)
      if (bitmap != null) {
        val artwork = androidx.core.graphics.drawable.RoundedBitmapDrawableFactory.create(resources, bitmap).apply {
          if (entry.optString("imageShape") == "circle") isCircular = true
          if (entry.optString("imageRendering") != "original") setTint(color(entry, "tint", tint))
        }
        return object : android.graphics.drawable.InsetDrawable(artwork, 0) {
          override fun getIntrinsicWidth() = dp(24.0)
          override fun getIntrinsicHeight() = dp(24.0)
        }
      }
      if (!TabImageLoader.hasFailed(uri)) TabImageLoader.load(context, uri) { actionJSON = ""; configure(config.toString()) }
    }
    val name = entry.optString("androidIcon").ifEmpty { when (entry.optString("systemItem")) { "search" -> "alg_tab_search"; "close", "cancel" -> "alg_nav_close"; "add" -> "alg_nav_add"; else -> "" } }
    val resource = resources.getIdentifier(name, "drawable", context.packageName)
    return if (resource == 0) null else context.getDrawable(resource)?.mutate()?.apply { setTint(color(entry, "tint", tint)) }
  }
  private fun updateActions(tint: Int) {
    val leading = config.optJSONArray("leading") ?: JSONArray(); val trailing = config.optJSONArray("trailing") ?: JSONArray()
    val footer = config.optJSONArray("toolbar") ?: JSONArray()
    leadingViews.forEach { toolbar.removeView(it) }; leadingViews.clear()
    toolbar.navigationIcon = null
    if (leading.length() > 0) {
      val first = leading.getJSONObject(0)
      toolbar.navigationIcon = drawable(first, tint) ?: context.getDrawable(com.adaptiveglass.R.drawable.alg_back)
      toolbar.navigationContentDescription = first.optString("label")
      toolbar.setNavigationOnClickListener { activate(first, toolbar) }
      // Native navigation icon view is public via Toolbar children, not private internals.
      for (i in 0 until toolbar.childCount) {
        val child = toolbar.getChildAt(i)
        if (child is android.widget.ImageButton && child.contentDescription == first.optString("label")) testID(child, first.optString("testID", first.getString("id")))
      }
      for (i in 1 until leading.length()) {
        val entry = leading.getJSONObject(i)
        val button = androidx.appcompat.widget.AppCompatImageButton(themed).apply {
          setImageDrawable(drawable(entry, tint)); contentDescription = entry.optString("label"); setBackgroundResource(android.R.drawable.list_selector_background)
          testID(this, entry.optString("testID", entry.getString("id"))); isEnabled = !entry.optBoolean("disabled"); setOnClickListener { activate(entry, this) }
        }
        toolbar.addView(button, androidx.appcompat.widget.Toolbar.LayoutParams(dp(48.0), dp(48.0), Gravity.START or Gravity.CENTER_VERTICAL)); leadingViews.add(button)
      }
    }
    val desired = mutableSetOf<Int>(); actionIDs.clear()
    for (i in 0 until trailing.length()) {
      val entry = trailing.getJSONObject(i); val number = menuNumbers.getOrPut(entry.getString("id")) { nextMenuNumber++ }; desired.add(number); actionIDs[number] = entry
      val item = toolbar.menu.findItem(number) ?: toolbar.menu.add(0, number, i, entry.optString("title", entry.optString("label")))
      item.title = entry.optString("title", entry.optString("label")); item.icon = drawable(entry, tint)
      item.isEnabled = !entry.optBoolean("disabled"); item.isCheckable = entry.has("selected"); item.isChecked = entry.optBoolean("selected")
      item.contentDescription = entry.optString("label") + (if (entry.has("badge")) ", " + entry.optString("badgeAccessibility", entry.optString("badge")) else "")
      item.setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
    }
    for (i in toolbar.menu.size() - 1 downTo 0) if (toolbar.menu.getItem(i).itemId !in desired) toolbar.menu.removeItem(toolbar.menu.getItem(i).itemId)
    toolbar.setOnMenuItemClickListener { item -> actionIDs[item.itemId]?.let { activate(it, toolbar.findViewById(item.itemId) ?: toolbar) }; true }
    post {
      for ((number, entry) in actionIDs) {
        val view = toolbar.findViewById<View>(number) ?: continue
        testID(view, entry.optString("testID", entry.getString("id")))
        badge(entry, view)
      }
    }
    bottomBar.removeAllViews()
    val explicit = (0 until footer.length()).any { footer.getJSONObject(it).has("spacer") }
    for (i in 0 until footer.length()) {
      val entry = footer.getJSONObject(i)
      if (!explicit && i > 0) bottomBar.addView(View(themed), LinearLayout.LayoutParams(0, 1, 1f))
      if (entry.has("spacer")) { bottomBar.addView(View(themed), LinearLayout.LayoutParams(if (entry.optString("spacer") == "flexible") 0 else dp(entry.optDouble("width", 12.0)), 1, if (entry.optString("spacer") == "flexible") 1f else 0f)); continue }
      val button = com.google.android.material.button.MaterialButton(themed, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
        text = entry.optString("title", entry.optString("label")); icon = drawable(entry, tint); contentDescription = entry.optString("label"); isEnabled = !entry.optBoolean("disabled")
        testID(this, entry.optString("testID", entry.getString("id"))); setOnClickListener { activate(entry, this) }
      }
      bottomBar.addView(button, LinearLayout.LayoutParams(-2, dp(48.0)))
    }
    bottomHeight = if (footer.length() > 0) dp(56.0) else 0
  }
  private val badges = mutableMapOf<View, com.google.android.material.badge.BadgeDrawable>()
  @OptIn(com.google.android.material.badge.ExperimentalBadgeUtils::class)
  private fun badge(entry: JSONObject, view: View) {
    badges.remove(view)?.let { com.google.android.material.badge.BadgeUtils.detachBadgeDrawable(it, view) }
    if (!entry.has("badge")) return
    val badge = com.google.android.material.badge.BadgeDrawable.create(themed)
    val text = entry.optString("badge"); if (text.isNotEmpty()) badge.text = text
    badge.backgroundColor = color(entry, "badgeColor", Color.RED); badge.badgeTextColor = color(entry, "badgeTextColor", Color.WHITE)
    com.google.android.material.badge.BadgeUtils.attachBadgeDrawable(badge, view); badges[view] = badge
  }
  private fun activate(entry: JSONObject, anchor: View) {
    if (entry.optBoolean("disabled")) return
    val items = entry.optJSONArray("menu")
    if (items == null) { action(entry.getString("id")); return }
    val popup = PopupMenu(themed, anchor)
    fun fill(menu: Menu, nodes: JSONArray, disabled: Boolean = false) {
      for (i in 0 until nodes.length()) {
        val child = nodes.getJSONObject(i); val unavailable = disabled || child.optBoolean("disabled")
        if (child.has("items")) {
          if (child.optString("kind") == "section") fill(menu, child.getJSONArray("items"), unavailable)
          else fill(menu.addSubMenu(child.getString("title")), child.getJSONArray("items"), unavailable)
        } else {
          val item = menu.add(child.getString("title")); item.isEnabled = !unavailable; item.isCheckable = child.has("checked"); item.isChecked = child.optBoolean("checked")
          item.setOnMenuItemClickListener { action(entry.getString("id"), child.getString("id")); true }
        }
      }
    }
    fill(popup.menu, items); popup.show()
  }
  private fun inset(name: String, automatic: Int): Int {
    if (config.opt(name) is Number) return dp(config.getDouble(name))
    val position = IntArray(2); getLocationInWindow(position)
    return if (name == "topInset") maxOf(0, automatic - position[1])
      else maxOf(0, position[1] + height - (rootView.height - automatic))
  }
  override fun onMeasure(widthSpec: Int, heightSpec: Int) {
    val width = MeasureSpec.getSize(widthSpec); val height = MeasureSpec.getSize(heightSpec); setMeasuredDimension(width, height)
    val top = inset("topInset", systemInsets.top); val bottomInset = inset("bottomInset", systemInsets.bottom)
    val innerWidth = maxOf(0, width - systemInsets.left - systemInsets.right)
    coordinator.measure(MeasureSpec.makeMeasureSpec(innerWidth, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(maxOf(0, height - top - bottomInset - bottomHeight), MeasureSpec.EXACTLY))
    bottomBar.measure(MeasureSpec.makeMeasureSpec(innerWidth, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(bottomHeight, MeasureSpec.EXACTLY))
    searchView.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY))
  }
  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    val top = inset("topInset", systemInsets.top); val bottomInset = inset("bottomInset", systemInsets.bottom); val left = systemInsets.left
    coordinator.layout(left, top, width - systemInsets.right, height - bottomInset - bottomHeight)
    bottomBar.layout(left, height - bottomInset - bottomHeight, width - systemInsets.right, height - bottomInset)
    searchView.layout(0, 0, width, height)
    reportInsets()
  }
  private fun reportInsets() {
    val top = inset("topInset", systemInsets.top) + dp(headerSize.toDouble()) + (if (searchBar.visibility == VISIBLE) searchBar.height else 0) + accessory.height + subtitleSlot.height + largeSubtitleSlot.height
    val bottom = inset("bottomInset", systemInsets.bottom) + bottomHeight
    val titleWidth = if (titleSlot.visibility == VISIBLE) maxOf(1, titleSlot.width) else dp(160.0)
    val key = "$top/$bottom/$titleWidth"
    if (id != NO_ID && width > 0 && key != lastInsets) { lastInsets = key; emit("topNavigationInsets", Arguments.createMap().apply { putDouble("top", px(top)); putDouble("bottom", px(bottom)); putDouble("titleWidth", px(titleWidth)) }) }
  }
  fun scrollToTop(animated: Boolean) { appBar.setExpanded(true, animated && android.animation.ValueAnimator.areAnimatorsEnabled()) }
  fun focusSearch() { if (config.has("search")) searchView.show() }
  fun dismissSearch() { programmaticDismiss = true; searchView.hide() }
}
