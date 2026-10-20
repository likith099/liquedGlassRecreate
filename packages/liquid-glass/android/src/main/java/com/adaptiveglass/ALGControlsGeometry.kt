package com.adaptiveglass

import android.content.Context
import android.graphics.Typeface
import android.text.TextPaint
import android.util.TypedValue
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.ceil

/**
 * One geometry function shared by [ALGControlsView] and [ALGControlsManager.measure], so the
 * Yoga size React Native lays out equals the size the view draws. It uses value APIs only
 * (TextPaint, resources), because measure() runs on React Native's layout thread.
 */
internal object ALGControlsGeometry {
  class Result(val widths: IntArray, val height: Int, val contentWidth: Int)

  fun compute(context: Context, config: JSONObject): Result {
    val metrics = context.resources.displayMetrics
    fun dp(n: Double) = (n * metrics.density + 0.5).toInt()
    val mode = config.optString("mode", "group")
    val items = config.optJSONArray("items") ?: JSONArray()
    val labelSize = config.optDouble("labelSize", 17.0)
    val height = dp(maxOf(44.0, config.optDouble("height", 44.0), labelSize + 20))
    val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
      textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, labelSize.toFloat(), metrics)
      letterSpacing = 0f
    }
    val padding = dp(if (mode == "group") 14.0 else config.optDouble("horizontalPadding", 15.0))
    val widths = IntArray(items.length())
    var content = 0
    for (index in 0 until items.length()) {
      val item = items.getJSONObject(index)
      val title = item.optString("title", "")
      val hasTitle = item.has("title") && title.isNotEmpty()
      val emphasized = item.optBoolean("selected", config.optString("value") == item.optString("id")) || item.optBoolean("prominent")
      val overlay = mode == "morph" || mode == "header"
      // Overlay titles and pills size from the regular label (pills: so selection never moves the
      // row); grouped titles are bold when emphasized.
      paint.typeface = if (!overlay && mode != "pills" && emphasized) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
      val textWidth = if (hasTitle) ceil(paint.measureText(title).toDouble()).toInt() else 0
      // A titled button reserves its icon box whether a remote image has loaded or not.
      val icon = if (hasTitle && !overlay && hasIcon(context, item)) dp(item.optJSONObject("symbol")?.optDouble("pointSize", 20.0) ?: 20.0) else 0
      widths[index] = when {
        overlay -> if (hasTitle) maxOf(height, textWidth + padding * 2) else height
        hasTitle -> textWidth + icon + padding * 2
        mode == "pills" -> dp(config.optDouble("iconCapsuleWidth", 49.0))
        else -> dp(config.optDouble("height", 44.0))
      }
      content += widths[index]
      if (mode == "pills" && index < items.length() - 1) content += dp(config.optDouble("gap", 10.0))
    }
    content += when (mode) {
      "pills" -> dp(config.optDouble("contentInset", 20.0)) * 2
      "group" -> dp(6.0) * 2
      else -> 0
    }
    return Result(widths, height, maxOf(1, content))
  }

  private fun hasIcon(context: Context, item: JSONObject): Boolean {
    if (!item.optJSONObject("imageSource")?.optString("uri").isNullOrEmpty()) return true
    val name = item.optString("androidIcon")
    return name.isNotEmpty() && context.resources.getIdentifier(name, "drawable", context.packageName) != 0
  }
}
