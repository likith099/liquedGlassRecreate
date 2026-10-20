package com.adaptiveglass
import android.content.Context
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput
import org.json.JSONObject
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.viewmanagers.ALGControlsManagerDelegate
import com.facebook.react.viewmanagers.ALGControlsManagerInterface
@ReactModule(name = "ALGControls")
class ALGControlsManager : SimpleViewManager<ALGControlsView>(), ALGControlsManagerInterface<ALGControlsView> {
  private val delegate = ALGControlsManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGControls"
  override fun createViewInstance(context: ThemedReactContext) = ALGControlsView(context)
  override fun setConfigJSON(view: ALGControlsView, value: String?) { view.configJSON = value ?: "{}" }
  override fun onAfterUpdateTransaction(view: ALGControlsView) { super.onAfterUpdateTransaction(view); view.applyConfiguration() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topControlAction" to mapOf("registrationName" to "onControlAction"))
  /** Called by the ALGControls shadow node during layout (layout thread), in density-independent pixels. */
  override fun measure(context: Context, localData: ReadableMap?, props: ReadableMap?, state: ReadableMap?,
    width: Float, widthMode: YogaMeasureMode, height: Float, heightMode: YogaMeasureMode, attachmentsPositions: FloatArray?): Long {
    val config = try { JSONObject(props?.getString("configJSON") ?: "{}") } catch (_: Exception) { JSONObject() }
    val geometry = ALGControlsGeometry.compute(context, config)
    val density = context.resources.displayMetrics.density
    var measured = geometry.contentWidth / density
    val mode = config.optString("mode", "group")
    // Pill rows scroll and header layers span their container: they take the offered width.
    if ((mode == "pills" || mode == "header") && widthMode != YogaMeasureMode.UNDEFINED) measured = width
    else if (widthMode == YogaMeasureMode.EXACTLY || (widthMode == YogaMeasureMode.AT_MOST && measured > width)) measured = width
    return YogaMeasureOutput.make(measured, maxOf(44f, geometry.height / density))
  }
}
