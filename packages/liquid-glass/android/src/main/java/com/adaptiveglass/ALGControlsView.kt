package com.adaptiveglass

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Menu
import android.view.animation.AccelerateInterpolator
import android.view.animation.LinearInterpolator
import android.view.animation.PathInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.TextView
import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.ReactAccessibilityDelegate
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

private class ControlsEvent(surfaceId: Int, tag: Int, private val name: String, private val payload: com.facebook.react.bridge.WritableMap) : Event<ControlsEvent>(surfaceId, tag) {
  override fun getEventName() = name
  override fun canCoalesce() = false
  override fun getEventData() = payload
}

/**
 * Morph and header slots keep one capsule per slot. A content change (icon ↔ title) animates the
 * capsule's width from its anchored edge while the outgoing content fades out and the incoming one
 * fades in; the badge sits on the capsule, so it rides that edge.
 */
private class Slot {
  var width = -1f
  var height = 0
  var kind = ""
  var target = -1
  var animator: ValueAnimator? = null
  var generation = 0
}

class ALGControlsView(private val reactContext: ThemedReactContext) : FrameLayout(reactContext) {
  var configJSON = "{}"
  private var applied = ""
  private var config = JSONObject()
  private val scroll = HorizontalScrollView(context)
  private val row = LinearLayout(context)
  private val buttons = mutableMapOf<String, Button>()
  private val holders = mutableMapOf<String, FrameLayout>()
  private val icons = mutableMapOf<String, ImageView>()
  private val titles = mutableMapOf<String, TextView>()
  private val badges = mutableMapOf<String, TextView>()
  private val slots = mutableMapOf<String, Slot>()
  /** Header slots that left: kept at their last frame while they shrink to their centre. */
  private val exiting = mutableMapOf<View, Rect>()
  private var popup: PopupMenu? = null
  private var overlayLaidOut = false
  private val density get() = resources.displayMetrics.density
  private fun dp(n: Double) = (n * density + 0.5).toInt()
  private val mode get() = config.optString("mode", "group")
  /** Morph and header lay their capsules out directly in this view, outside the clipping scroll row. */
  private val isOverlay get() = mode == "morph" || mode == "header"
  /** Header slots keep one capsule across screens; `id` stays route-qualified for presses. */
  private fun slotKey(item: JSONObject) = item.optString("slot").ifEmpty { item.getString("id") }
  /** Header: the focused screen's slot keys → the capsules they took over (see [pairSlots]). */
  private var slotAliases = mutableMapOf<String, String>()
  private var shownRoute: String? = null
  private var shownItems = listOf<JSONObject>()
  /** The same control on two screens: same side and visible content (badge and tint may change). */
  private fun sameContent(a: JSONObject, b: JSONObject) =
    listOf("side", "title", "androidIcon").all { a.optString(it) == b.optString(it) } &&
      listOf("symbol", "imageSource").all { a.optJSONObject(it)?.toString() == b.optJSONObject(it)?.toString() }
  /**
   * Header slot pairing when the focused screen changes, as the system bar pairs its items: a
   * named slot on both screens keeps its capsule and morphs its content; a control on both screens
   * (same side and content, at any position or slot name) keeps its capsule and stays still, like
   * a back button; the rest pair by position on each side and morph. Within a screen the pairing
   * holds, so a carried control still morphs when its own content changes. Rewrites `slot`.
   */
  private fun pairSlots(items: JSONArray) {
    val next = (0 until items.length()).map { items.getJSONObject(it) }
    val route = config.optString("active").ifEmpty { null }
    if (route != shownRoute) {
      shownRoute = route; slotAliases = mutableMapOf()
      val taken = mutableSetOf<String>()
      fun claim(item: JSONObject, key: String) { slotAliases[slotKey(item)] = key; taken.add(key) }
      val shownKeys = shownItems.map(::slotKey).toSet()
      next.filter { it.optBoolean("slotNamed") && slotKey(it) in shownKeys }.forEach { claim(it, slotKey(it)) }
      next.filter { slotKey(it) !in slotAliases }.forEach { item ->
        shownItems.firstOrNull { slotKey(it) !in taken && sameContent(it, item) }?.let { claim(item, slotKey(it)) }
      }
      next.filter { slotKey(it) !in slotAliases }.forEach { item ->
        shownItems.firstOrNull { slotKey(it) !in taken && it.optString("side") == item.optString("side") }?.let { claim(item, slotKey(it)) }
      }
    }
    val used = next.mapNotNull { slotAliases[slotKey(it)] }.toMutableSet()
    for (item in next) {
      val original = slotKey(item)
      val key = slotAliases[original] ?: generateSequence(original) { it + "\u0002" }.first { it !in used }
      used.add(key); slotAliases[original] = key; item.put("slot", key)
    }
    shownItems = next
  }
  private fun animationsEnabled() = isAttachedToWindow && (android.os.Build.VERSION.SDK_INT < 26 || ValueAnimator.areAnimatorsEnabled())
  init {
    clipChildren = false; clipToPadding = false
    row.orientation = LinearLayout.HORIZONTAL; row.gravity = Gravity.CENTER_VERTICAL
    scroll.isHorizontalScrollBarEnabled = false; scroll.addView(row)
    addView(scroll, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
  }
  private fun emit(name: String, payload: com.facebook.react.bridge.WritableMap) {
    UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(ControlsEvent(UIManagerHelper.getSurfaceId(reactContext), id, name, payload))
  }
  fun applyConfiguration() {
    if (applied == configJSON) return
    applied = configJSON; config = try { JSONObject(configJSON) } catch (_: Exception) { JSONObject() }
    val mode = mode
    val overlay = isOverlay
    scroll.visibility = if (overlay) View.GONE else View.VISIBLE
    val items = config.optJSONArray("items") ?: JSONArray()
    if (mode == "header") pairSlots(items)
    // The same widths React Native measured for this view (see ALGControlsGeometry).
    val geometry = ALGControlsGeometry.compute(context, config)
    val keys = (0 until items.length()).map { slotKey(items.getJSONObject(it)) }.toSet()
    buttons.keys.toList().filter { it !in keys }.forEach { key ->
      val holder = holders.remove(key)
      buttons.remove(key)?.isEnabled = false
      badges.remove(key); icons.remove(key); titles.remove(key)
      slots.remove(key)?.let { it.animator?.cancel(); it.generation++ }
      if (holder != null) {
        if (mode == "header" && holder.parent === this && holder.width > 0 && animationsEnabled()) dematerialize(holder)
        else (holder.parent as? ViewGroup)?.removeView(holder)
      }
    }
    val dark = config.optString("colorScheme") == "dark" || (config.optString("colorScheme") != "light" &&
      resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK == android.content.res.Configuration.UI_MODE_NIGHT_YES)
    val fill = if (dark) Color.rgb(40, 42, 47) else Color.rgb(240, 241, 245)
    val ink = if (dark) Color.WHITE else Color.rgb(28, 28, 30)
    val inset = if (mode == "pills") config.optDouble("contentInset", 20.0) else if (mode == "group") 6.0 else 0.0
    row.setPadding(dp(inset), 0, dp(inset), 0)
    row.background = if (mode == "group") GradientDrawable().apply { setColor(fill); cornerRadius = dp(100.0).toFloat() } else null
    for (index in 0 until items.length()) {
      val item = items.getJSONObject(index); val key = slotKey(item); val itemID = item.getString("id")
      val appearing = !holders.containsKey(key)
      val button = buttons.getOrPut(key) { Button(context).apply {
        isAllCaps = false; minWidth = 0; minimumWidth = 0; minHeight = 0; minimumHeight = 0
        stateListAnimator = null; elevation = 0f
        maxLines = 1; gravity = Gravity.CENTER
      } }
      // Icon and title overlays come before the badge so the badge always draws on top.
      val holder = holders.getOrPut(key) { FrameLayout(context).apply {
        clipChildren = false; clipToPadding = false
        addView(button, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
      } }
      val icon = icons.getOrPut(key) { ImageView(context).apply {
        isClickable = false; isFocusable = false; importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        scaleType = ImageView.ScaleType.FIT_CENTER
        holder.addView(this, FrameLayout.LayoutParams(0, 0, Gravity.CENTER))
      } }
      val title = titles.getOrPut(key) { TextView(context).apply {
        isClickable = false; isFocusable = false; importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        maxLines = 1; gravity = Gravity.CENTER; visibility = View.GONE
        holder.addView(this, FrameLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.CENTER))
      } }
      if (overlay) {
        if (holder.parent !== this) { (holder.parent as? ViewGroup)?.removeView(holder); addView(holder) }
      } else if (holder.parent !== row || row.indexOfChild(holder) != index) {
        (holder.parent as? ViewGroup)?.removeView(holder); row.addView(holder, index)
      }
      val badge = badges.getOrPut(key) { TextView(context).apply {
        gravity = Gravity.CENTER; textSize = 11f; setTextColor(Color.WHITE); isClickable = false
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        holder.addView(this)
      } }
      val badgeText = if (item.has("badge") && !item.isNull("badge")) item.optString("badge") else null
      badge.visibility = if (badgeText == null) View.GONE else View.VISIBLE; badge.text = badgeText
      val badgeHeight = dp(if (badgeText?.isEmpty() == true) 8.0 else 18.0)
      badge.minimumWidth = badgeHeight
      val badgePadding = if (badgeText?.isEmpty() == true) 0 else dp(4.0)
      badge.setPadding(badgePadding, 0, badgePadding, 0)
      badge.layoutParams = FrameLayout.LayoutParams(LayoutParams.WRAP_CONTENT, badgeHeight, Gravity.TOP or Gravity.END)
      badge.background = GradientDrawable().apply { cornerRadius = badgeHeight / 2f
        setColor(if (item.has("badgeColor")) item.getDouble("badgeColor").toLong().toInt() else Color.RED) }
      badge.setTextColor(if (item.has("badgeTextColor")) item.getDouble("badgeTextColor").toLong().toInt() else Color.WHITE)
      val selected = item.optBoolean("selected", config.optString("value") == itemID)
      val emphasized = selected || item.optBoolean("prominent")
      val tint = if (item.has("tint")) item.getDouble("tint").toLong().toInt() else if (config.has("tint")) config.getDouble("tint").toLong().toInt() else ink
      val surface = if (emphasized) tint else fill
      button.background = RippleDrawable(ColorStateList.valueOf(0x40808080),
        if (mode == "group" && !emphasized) null else GradientDrawable().apply { setColor(surface); cornerRadius = dp(100.0).toFloat() },
        GradientDrawable().apply { setColor(Color.WHITE); cornerRadius = dp(100.0).toFloat() })
      val titleText = item.optString("title", "")
      val hasTitle = item.has("title") && titleText.isNotEmpty()
      val labelSize = config.optDouble("labelSize", 17.0).toFloat()
      val textColor = if (emphasized) (if (dark) Color.BLACK else Color.WHITE) else tint
      val typeface = if (emphasized) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL
      button.textSize = labelSize; button.letterSpacing = 0f
      button.isSelected = selected; button.isEnabled = !config.optBoolean("disabled") && !item.optBoolean("disabled")
      val label = item.optString("label", item.optString("title"))
      // TalkBack reads the badge as JS spells it ("3 new", the text, "New" for a dot, or the app's label).
      val spokenBadge = if (badgeText == null) null else item.optString("badgeAccessibility").ifEmpty { badgeText.ifEmpty { "New" } }
      button.contentDescription = label + (if (spokenBadge != null) ", $spokenBadge" else "")
      button.setTag(com.facebook.react.R.id.react_test_id, item.optString("testID", key))
      ReactAccessibilityDelegate.setDelegate(button, button.isFocusable, button.importantForAccessibility)
      val drawableName = item.optString("androidIcon")
      val drawableId = if (drawableName.isEmpty()) 0 else resources.getIdentifier(drawableName, "drawable", context.packageName)
      val iconSize = dp(item.optJSONObject("symbol")?.optDouble("pointSize", 20.0) ?: 20.0)
      var drawable: Drawable? = if (drawableId == 0) null else context.getDrawable(drawableId)?.mutate()
      drawable?.setBounds(0, 0, iconSize, iconSize); drawable?.setTint(if (mode == "group" && emphasized) textColor else tint)
      val uri = item.optJSONObject("imageSource")?.optString("uri")
      if (!uri.isNullOrEmpty()) {
        val bitmap = TabImageLoader.cached(uri)
        if (bitmap != null) drawable = android.graphics.drawable.BitmapDrawable(resources, bitmap).apply { setBounds(0, 0, iconSize, iconSize) }
        else if (!TabImageLoader.hasFailed(uri)) TabImageLoader.load(context, uri) { applied = ""; applyConfiguration() }
      }
      val padding = dp(if (mode == "group") 14.0 else config.optDouble("horizontalPadding", 15.0))
      // A selected pill keeps its regular-label width (ALGControlsGeometry): the bold label takes the
      // difference from its padding, so it never wraps or moves the row.
      val titlePadding = if (mode == "pills" && hasTitle && emphasized) {
        val probe = android.text.TextPaint(button.paint)
        probe.typeface = android.graphics.Typeface.DEFAULT; val regular = probe.measureText(titleText)
        probe.typeface = android.graphics.Typeface.DEFAULT_BOLD; val bold = probe.measureText(titleText)
        maxOf(dp(4.0), padding - kotlin.math.ceil((bold - regular) / 2.0).toInt())
      } else padding
      button.setPadding(titlePadding, 0, titlePadding, 0)
      val h = dp(maxOf(44.0, config.optDouble("height", 44.0), (labelSize + 20).toDouble()))
      // An icon-only control centres its glyph in its own view; a compound drawable sits after the
      // padding and lands off-centre in a 44 dp circle.
      fun showIcon(image: Drawable?) {
        icon.setImageDrawable(image)
        icon.layoutParams = FrameLayout.LayoutParams(iconSize, iconSize, Gravity.CENTER)
      }
      if (overlay) {
        // The button keeps the capsule, ripple, click and accessibility; content is overlaid so the
        // outgoing glyph or title can fade out while the incoming one fades in.
        button.text = ""; button.setCompoundDrawables(null, null, null, null)
        title.text = titleText.ifEmpty { title.text }
        title.textSize = labelSize; title.setTextColor(tint); title.setTypeface(null, android.graphics.Typeface.NORMAL)
        title.visibility = View.VISIBLE; icon.visibility = View.VISIBLE
        if (!hasTitle) showIcon(drawable)
        title.letterSpacing = 0f
        val target = geometry.widths[index]
        holder.layoutParams = FrameLayout.LayoutParams(target, h)
        updateSlot(key, if (hasTitle) "title" else "icon", target, h, icon, title)
        // A header control that arrives with the screen fades in at full size, as UIKit's bar does.
        if (appearing && mode == "header" && overlayLaidOut && animationsEnabled()) {
          holder.alpha = 0f; holder.animate().alpha(1f).setDuration(150).setInterpolator(LinearInterpolator()).start()
        }
      } else {
        title.visibility = View.GONE
        if (hasTitle) {
          button.text = titleText; button.setTextColor(textColor); button.setTypeface(null, typeface)
          button.setCompoundDrawables(drawable, null, null, null)
          icon.visibility = View.GONE
        } else {
          button.text = ""; button.setCompoundDrawables(null, null, null, null)
          icon.visibility = if (drawable == null) View.GONE else View.VISIBLE; icon.alpha = 1f
          showIcon(drawable)
        }
        val w = geometry.widths[index]
        holder.layoutParams = LinearLayout.LayoutParams(w, h).apply { marginEnd = if (index < items.length() - 1 && mode == "pills") dp(config.optDouble("gap", 10.0)) else 0 }
      }
      button.setOnClickListener {
        if (config.optBoolean("disabled") || item.optBoolean("disabled")) return@setOnClickListener
        if (item.optString("pressEffect") == "bounce" && (android.os.Build.VERSION.SDK_INT < 26 || ValueAnimator.areAnimatorsEnabled())) {
          button.animate().scaleX(1.15f).scaleY(1.15f).setDuration(75).withEndAction { button.animate().scaleX(1f).scaleY(1f).setDuration(150).start() }.start()
        }
        val menu = item.optJSONArray("menu")
        if (menu != null) showMenu(button, itemID, menu)
        else emit("topControlAction", Arguments.createMap().apply { putString("id", itemID); putString("action", "") })
      }
    }
    requestLayout()
    post { if (isAttachedToWindow) { measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)); layout(left, top, right, bottom) } }
  }

  /** Snaps on first configuration, without animations, or off-window; otherwise morphs the capsule. */
  private fun updateSlot(key: String, kind: String, target: Int, height: Int, icon: ImageView, title: TextView) {
    val slot = slots.getOrPut(key) { Slot() }
    val morph = mode == "morph"
    slot.height = height
    val iconAlpha = if (kind == "icon") 1f else 0f
    val titleAlpha = if (kind == "title") 1f else 0f
    if (slot.width < 0f || !animationsEnabled()) {
      slot.animator?.cancel(); slot.generation++
      slot.width = target.toFloat(); slot.kind = kind; slot.target = target
      icon.alpha = iconAlpha; title.alpha = titleAlpha
      return
    }
    // A config re-apply for anything else (badge, tint, label) must not restart the morph.
    if (kind == slot.kind && target == slot.target) return
    slot.animator?.cancel()
    val generation = ++slot.generation
    val from = slot.width
    val iconFrom = icon.alpha; val titleFrom = title.alpha
    slot.kind = kind; slot.target = target
    val ease = PathInterpolator(0.05f, 0.7f, 0.1f, 1f) // Material emphasized decelerate
    fun fade(from: Float, to: Float, t: Float) = if (to > from)
      from + (to - from) * ((t - 0.2f) / 0.5f).coerceIn(0f, 1f) // incoming: after the shape has opened
    else from + (to - from) * (t / 0.22f).coerceIn(0f, 1f)       // outgoing: clears quickly
    slot.animator = ValueAnimator.ofFloat(0f, 1f).apply {
      duration = if (morph) 420 else 300; interpolator = LinearInterpolator()
      addUpdateListener { animation ->
        if (generation != slot.generation) return@addUpdateListener
        val t = animation.animatedValue as Float
        slot.width = from + (target - from) * ease.getInterpolation(t)
        icon.alpha = fade(iconFrom, iconAlpha, t); title.alpha = fade(titleFrom, titleAlpha, t)
        layoutOverlay()
      }
      addListener(object : AnimatorListenerAdapter() {
        override fun onAnimationEnd(animation: Animator) {
          if (generation != slot.generation) return
          slot.width = target.toFloat(); icon.alpha = iconAlpha; title.alpha = titleAlpha
          layoutOverlay()
        }
      })
      start()
    }
  }
  /** A header control that leaves shrinks to its centre and fades, like UIKit's bar items. */
  private fun dematerialize(holder: FrameLayout) {
    exiting[holder] = Rect(holder.left, holder.top, holder.right, holder.bottom)
    holder.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
    holder.pivotX = holder.width / 2f; holder.pivotY = holder.height / 2f
    holder.animate().scaleX(0.3f).scaleY(0.3f).alpha(0f).setDuration(120).setInterpolator(AccelerateInterpolator())
      .withEndAction { exiting.remove(holder); removeView(holder) }.start()
  }
  private fun placeSlot(key: String, x: Int) {
    val holder = holders[key] ?: return; val slot = slots[key] ?: return
    val w = maxOf(1, slot.width.roundToInt()); val h = if (slot.height > 0) slot.height else height
    val y = maxOf(0, (height - h) / 2)
    holder.measure(MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY))
    holder.layout(x, y, x + w, y + h)
    // Content stays inside the capsule, as glass clips its content; the badge stays unclipped so
    // it can sit over the edge.
    val inset = dp(6.0)
    for (content in listOfNotNull(titles[key], icons[key])) {
      val start = maxOf(0, inset - content.left); val end = minOf(content.width, w - inset - content.left)
      content.clipBounds = if (end > start) Rect(start, 0, end, content.height) else Rect()
    }
  }
  private fun slotWidth(key: String) = maxOf(1, slots[key]?.width?.roundToInt() ?: 0)
  private fun layoutOverlay() {
    val items = config.optJSONArray("items") ?: JSONArray()
    if (mode == "morph") {
      val key = holders.keys.firstOrNull() ?: return
      val w = slotWidth(key)
      placeSlot(key, when (config.optString("anchor", "trailing")) {
        "leading" -> 0
        "center" -> (width - w) / 2
        else -> width - w
      })
    } else {
      // Header: leading slots from the leading inset, trailing slots back from the trailing inset,
      // each at its animated width, so a morphing slot keeps the edge it is anchored to.
      var leading = dp(config.optDouble("contentInset", 20.0)); var trailing = width - leading
      for (index in 0 until items.length()) {
        val item = items.getJSONObject(index); val key = slotKey(item)
        if (!holders.containsKey(key)) continue
        val w = slotWidth(key)
        if (item.optString("side") == "trailing") { trailing -= w; placeSlot(key, trailing); trailing -= dp(12.0) }
        else { placeSlot(key, leading); leading += w + dp(12.0) }
      }
    }
    exiting.forEach { (view, rect) -> view.layout(rect.left, rect.top, rect.right, rect.bottom) }
  }

  private fun showMenu(button: Button, id: String, items: JSONArray) {
    popup?.dismiss()
    val next = PopupMenu(context, button)
    fun fill(menu: Menu, nodes: JSONArray, parentEnabled: Boolean = true) {
      for (index in 0 until nodes.length()) {
        val item = nodes.getJSONObject(index); val children = item.optJSONArray("items")
        val enabled = parentEnabled && !item.optBoolean("disabled")
        if (children != null) {
          if (item.optString("kind") == "section") fill(menu, children, enabled)
          else { val sub = menu.addSubMenu(item.getString("title")); sub.item.isEnabled = enabled; fill(sub, children, enabled) }
        } else menu.add(item.getString("title")).apply {
          isEnabled = enabled; isCheckable = item.has("checked"); isChecked = item.optBoolean("checked")
          setOnMenuItemClickListener { emit("topControlAction", Arguments.createMap().apply { putString("id", id); putString("action", item.getString("id")) }); true }
        }
      }
    }
    fill(next.menu, items); popup = next; next.show()
  }
  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    super.onLayout(changed, l, t, r, b)
    if (isOverlay) {
      // React drives this view's size; each capsule follows its own animated width.
      layoutOverlay(); overlayLaidOut = true; return
    }
    row.measure(MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
    row.layout(0, 0, row.measuredWidth, row.measuredHeight)
    if (mode == "pills" && config.optBoolean("scrollSelectedIntoView", true)) {
      holders[config.optString("value")]?.let { selected ->
        if (selected.left < scroll.scrollX || selected.right > scroll.scrollX + width) scroll.smoothScrollTo(maxOf(0, selected.left - row.paddingLeft), 0)
      }
    }
  }
  override fun onDetachedFromWindow() {
    slots.values.forEach { it.animator?.cancel(); it.generation++ }
    exiting.keys.toList().forEach { it.animate().cancel(); removeView(it) }; exiting.clear()
    popup?.dismiss(); popup = null; super.onDetachedFromWindow()
  }
}
