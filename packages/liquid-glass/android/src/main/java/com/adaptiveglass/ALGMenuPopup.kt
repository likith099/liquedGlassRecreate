package com.adaptiveglass

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.TextUtils
import android.transition.Fade
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.BaseAdapter
import android.widget.Checkable
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.PopupWindow
import android.widget.TextView
import org.json.JSONObject

/** The menu popup's shape and colours for one appearance. */
internal data class MenuStyle(val cornerRadius: Float, val background: Int, val text: Int, val icon: Int,
  val destructive: Int, val divider: Int) {
  companion object {
    /**
     * Reads `menuStyleJSON` from JavaScript: `cornerRadius` in dp, and each colour as
     * `{light, dark}` ARGB numbers. Unset values use the defaults for [dark].
     */
    fun from(json: String, dark: Boolean): MenuStyle {
      val style = try { if (json.isEmpty()) JSONObject() else JSONObject(json) } catch (_: Exception) { JSONObject() }
      fun color(key: String, light: Int, darkDefault: Int): Int {
        val pair = style.optJSONObject(key)
        val scheme = if (dark) "dark" else "light"
        return if (pair != null && pair.has(scheme)) pair.getDouble(scheme).toLong().toInt()
          else if (dark) darkDefault else light
      }
      val text = color("textColor", 0xFF1B1B1F.toInt(), 0xFFE3E3E8.toInt())
      return MenuStyle(
        cornerRadius = if (style.has("cornerRadius")) style.getDouble("cornerRadius").toFloat() else 16f,
        background = color("backgroundColor", 0xFFFFFFFF.toInt(), 0xFF1A1B20.toInt()),
        text = text,
        icon = color("iconColor", 0xFF46464F.toInt(), 0xFFB9BAC2.toInt()),
        destructive = color("destructiveColor", 0xFFBA1A1A.toInt(), 0xFFFFB4AB.toInt()),
        divider = Color.argb(0x1F, Color.red(text), Color.green(text), Color.blue(text)))
    }
  }
}

/** A menu row that reports its checked state to accessibility services. */
internal class MenuRow(context: Context) : LinearLayout(context), Checkable {
  var checkable = false
  private var checkedState = false
  override fun isChecked() = checkedState
  override fun setChecked(checked: Boolean) { checkedState = checked; refreshDrawableState() }
  override fun toggle() { isChecked = !checkedState }
  override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
    super.onInitializeAccessibilityNodeInfo(info)
    info.isCheckable = checkable
    val checked = checkable && checkedState
    if (android.os.Build.VERSION.SDK_INT >= 36) {
      info.setChecked(if (checked) AccessibilityNodeInfo.CHECKED_STATE_TRUE else AccessibilityNodeInfo.CHECKED_STATE_FALSE)
    } else {
      @Suppress("DEPRECATION")
      info.isChecked = checked
    }
  }
}

private sealed class Row {
  class Item(val entry: MenuEntry) : Row()
  class Title(val text: String) : Row()
  object Divider : Row()
  class Back(val title: String) : Row()
}

/**
 * The menu popup for menu buttons, icon buttons and context menus: a rounded surface with an
 * icon, title and indicator per item, section titles and dividers, and submenus shown in place
 * with a back row. Rows are in a ListView and report their enabled and checked states.
 */
internal class ALGMenuPopup(
  private val context: Context,
  private val entries: List<MenuEntry>,
  private val style: MenuStyle,
  /** Every item is disabled, as when the control is. */
  private val allDisabled: Boolean,
  /** Title colour for ordinary items; the style's text colour when null. */
  private val tint: Int?,
  /** Narrowest the popup may be, in dp; Material's minimum is 112. */
  private val minWidthDp: Float = 112f,
  private val onSelect: (MenuEntry) -> Unit,
  onDismiss: () -> Unit,
) {
  private val density = context.resources.displayMetrics.density
  private fun dp(value: Float) = (value * density).toInt()
  private val list = ListView(context).apply {
    divider = null
    dividerHeight = 0
    selector = ColorDrawable(Color.TRANSPARENT)
    isVerticalScrollBarEnabled = false
    overScrollMode = View.OVER_SCROLL_NEVER
  }
  private val surface = FrameLayout(context).apply {
    setPadding(0, dp(8f), 0, dp(8f))
    // Clip the rows' ripples to the rounded surface.
    outlineProvider = object : ViewOutlineProvider() {
      override fun getOutline(view: View, outline: Outline) =
        outline.setRoundRect(0, 0, view.width, view.height, style.cornerRadius * density)
    }
    clipToOutline = true
    addView(list, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
  }
  private val window = PopupWindow(surface, ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, true).apply {
    setBackgroundDrawable(GradientDrawable().apply {
      setColor(style.background)
      cornerRadius = style.cornerRadius * density
    })
    elevation = 8f * density
    isOutsideTouchable = true
    inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
    enterTransition = Fade().apply { duration = 150 }
    exitTransition = Fade().apply { duration = 100 }
    setOnDismissListener { onDismiss() }
  }
  private val views = MenuRowViews(context, style, tint)
  private var rows: List<Row> = emptyList()
  private val adapter = object : BaseAdapter() {
    override fun getCount() = rows.size
    override fun getItem(position: Int) = rows[position]
    override fun getItemId(position: Int) = position.toLong()
    override fun getViewTypeCount() = 4
    override fun getItemViewType(position: Int) = when (rows[position]) {
      is Row.Item -> 0; is Row.Title -> 1; Row.Divider -> 2; is Row.Back -> 3
    }
    override fun areAllItemsEnabled() = false
    override fun isEnabled(position: Int) = when (val row = rows[position]) {
      is Row.Item -> enabled(row.entry)
      is Row.Back -> true
      else -> false
    }
    // Rows are few and rebuilt on navigation, so each is built fresh rather than recycled.
    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View = when (val row = rows[position]) {
      is Row.Item -> views.item(row.entry, enabled(row.entry), rows.any { it is Row.Item && it.entry.androidIcon.isNotEmpty() })
      is Row.Title -> views.title(row.text)
      Row.Divider -> views.divider().apply {
        layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(17f))
      }
      is Row.Back -> backView(row.title)
    }
  }

  init {
    list.adapter = adapter
    list.setOnItemClickListener { _, _, position, _ ->
      when (val row = rows[position]) {
        is Row.Item -> if (enabled(row.entry)) {
          if (row.entry.kind == "submenu") show(submenuRows(row.entry)) else { window.dismiss(); onSelect(row.entry) }
        }
        is Row.Back -> show(rows(entries))
        else -> Unit
      }
    }
  }

  private fun enabled(entry: MenuEntry) = !allDisabled && !entry.disabled

  /** Sections become an optional title between dividers; submenus are rows that open in place. */
  private fun rows(nodes: List<MenuEntry>): List<Row> {
    val out = mutableListOf<Row>()
    for (entry in nodes) {
      if (entry.kind == "section") {
        if (out.isNotEmpty() && out.last() != Row.Divider) out.add(Row.Divider)
        if (entry.title.isNotEmpty()) out.add(Row.Title(entry.title))
        out.addAll(rows(entry.items))
        out.add(Row.Divider)
      } else out.add(Row.Item(entry))
    }
    while (out.lastOrNull() == Row.Divider) out.removeAt(out.size - 1)
    return out
  }
  private fun submenuRows(entry: MenuEntry) = listOf(Row.Back(entry.title), Row.Divider) + rows(entry.items)

  private fun backView(title: String) = LinearLayout(context).apply {
    orientation = LinearLayout.HORIZONTAL
    gravity = Gravity.CENTER_VERTICAL
    minimumHeight = dp(52f)
    setPaddingRelative(dp(16f), 0, dp(20f), 0)
    background = views.ripple()
    addView(views.label("‹", style.icon, 20f), LinearLayout.LayoutParams(dp(24f), ViewGroup.LayoutParams.WRAP_CONTENT).apply {
      marginEnd = dp(16f)
    })
    addView(views.label(title, style.text).apply { setTypeface(typeface, Typeface.BOLD) })
    contentDescription = "Back, $title"
  }

  /** Width from the widest row across every level, so the popup keeps its size while navigating. */
  private fun measuredWidth(): Int {
    val levels = mutableListOf(rows(entries))
    fun collect(nodes: List<MenuEntry>) {
      for (entry in nodes) {
        if (entry.kind == "submenu") levels.add(submenuRows(entry))
        if (entry.kind == "section") collect(entry.items)
      }
    }
    collect(entries)
    val unspecified = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    var widest = 0
    for (level in levels) {
      rows = level
      for (position in level.indices) {
        val view = adapter.getView(position, null, list)
        view.measure(unspecified, unspecified)
        widest = maxOf(widest, view.measuredWidth)
      }
    }
    val screen = context.resources.displayMetrics.widthPixels
    val max = minOf(dp(280f), screen - dp(32f))
    return widest.coerceIn(minOf(dp(minWidthDp), max), max)
  }

  private fun contentHeight(width: Int): Int {
    val exactly = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
    val unspecified = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    var total = dp(16f)
    for (position in rows.indices) {
      val view = adapter.getView(position, null, list)
      view.measure(exactly, unspecified)
      total += view.measuredHeight
    }
    return minOf(total, context.resources.displayMetrics.heightPixels - dp(96f))
  }

  private fun show(next: List<Row>) {
    rows = next
    adapter.notifyDataSetChanged()
    if (window.isShowing) window.update(window.width, contentHeight(window.width))
  }

  val isShowing get() = window.isShowing

  /** The space the popup needs below its anchor: its height plus the 6 dp gap. */
  fun heightBelowAnchor(): Int {
    val width = measuredWidth()
    rows = rows(entries)
    return contentHeight(width) + dp(6f)
  }

  /**
   * Shows the popup below [anchor], aligned to its nearer screen edge; the window moves above the
   * anchor when there is no room below.
   */
  fun showAt(anchor: View) {
    val width = measuredWidth()
    rows = rows(entries)
    adapter.notifyDataSetChanged()
    window.width = width
    window.height = contentHeight(width)
    val location = IntArray(2).also { anchor.getLocationOnScreen(it) }
    val onRight = location[0] + anchor.width / 2 > context.resources.displayMetrics.widthPixels / 2
    window.showAsDropDown(anchor, 0, dp(6f), if (onRight) Gravity.END else Gravity.START)
  }

  /**
   * Shows the popup over [anchor]'s frame, at its position and width: GlassMenuPanel gives the anchor
   * the menu's own frame, so the menu appears exactly there.
   */
  fun showOver(anchor: View) {
    rows = rows(entries)
    adapter.notifyDataSetChanged()
    val width = anchor.width.coerceAtLeast(dp(112f))
    val location = IntArray(2).also { anchor.getLocationInWindow(it) }
    val below = context.resources.displayMetrics.heightPixels - location[1]
    window.width = width
    window.height = minOf(contentHeight(width), maxOf(below, dp(48f)))
    window.showAtLocation(anchor, Gravity.NO_GRAVITY, location[0], location[1])
  }

  fun dismiss() = window.dismiss()
}

/** Row views shared by the menu popup and GlassMenuPanel, so both look the same. */
internal class MenuRowViews(private val context: Context, private val style: MenuStyle, private val tint: Int?) {
  private val density = context.resources.displayMetrics.density
  private fun dp(value: Float) = (value * density).toInt()

  fun ripple() = RippleDrawable(ColorStateList.valueOf(Color.argb(0x1F, Color.red(style.text),
    Color.green(style.text), Color.blue(style.text))), null, ColorDrawable(Color.WHITE))

  private fun iconDrawable(name: String): Drawable? {
    if (name.isEmpty()) return null
    val resource = context.resources.getIdentifier(name, "drawable", context.packageName)
    return if (resource == 0) null else context.getDrawable(resource)?.mutate()
  }

  fun label(text: String, color: Int, size: Float = 16f) = TextView(context).apply {
    this.text = text
    setTextColor(color)
    setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
    maxLines = 1
    ellipsize = TextUtils.TruncateAt.END
  }

  fun item(entry: MenuEntry, enabled: Boolean, reserveIcon: Boolean): MenuRow {
    val titleColor = if (entry.destructive) style.destructive else tint ?: style.text
    val iconColor = if (entry.destructive) style.destructive else style.icon
    return MenuRow(context).apply {
      orientation = LinearLayout.HORIZONTAL
      gravity = Gravity.CENTER_VERTICAL
      minimumHeight = dp(52f)
      setPaddingRelative(dp(16f), 0, dp(20f), 0)
      background = ripple()
      if (reserveIcon) addView(ImageView(context).apply {
        setImageDrawable(iconDrawable(entry.androidIcon))
        imageTintList = ColorStateList.valueOf(iconColor)
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
      }, LinearLayout.LayoutParams(dp(24f), dp(24f)).apply { marginEnd = dp(16f) })
      addView(label(entry.title, titleColor), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
      val indicator = when {
        entry.kind == "submenu" -> "›"
        entry.checked == true -> "✓"
        else -> null
      }
      if (indicator != null) addView(label(indicator, style.icon, 18f).apply {
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
      }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
        marginStart = dp(16f)
      })
      checkable = entry.kind != "submenu" && entry.checked != null
      isChecked = entry.checked == true
      isEnabled = enabled
      alpha = if (enabled) 1f else 0.38f
      contentDescription = entry.title
    }
  }

  fun title(text: String) = label(text, style.icon, 14f).apply {
    setTypeface(typeface, Typeface.BOLD)
    minHeight = dp(36f)
    gravity = Gravity.CENTER_VERTICAL
    setPaddingRelative(dp(16f), 0, dp(20f), 0)
  }

  /** A section divider: a hairline centred in its row's height. */
  fun divider() = View(context).apply {
    background = android.graphics.drawable.InsetDrawable(GradientDrawable().apply { setColor(style.divider) }, 0, dp(8f), 0, dp(8f))
    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
  }
}
