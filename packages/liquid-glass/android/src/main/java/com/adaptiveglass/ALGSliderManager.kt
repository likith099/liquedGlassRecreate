package com.adaptiveglass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.viewmanagers.ALGSliderManagerDelegate
import com.facebook.react.viewmanagers.ALGSliderManagerInterface

@ReactModule(name = "ALGSlider")
class ALGSliderManager : SimpleViewManager<ALGSliderView>(), ALGSliderManagerInterface<ALGSliderView> {
  private val delegate = ALGSliderManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGSlider"
  override fun createViewInstance(context: ThemedReactContext) = ALGSliderView(context)
  override fun setValue(view: ALGSliderView, value: Double) { view.controlledValue = value }
  override fun setMinimumValue(view: ALGSliderView, value: Double) { view.minimum = value }
  override fun setMaximumValue(view: ALGSliderView, value: Double) { view.maximum = value }
  override fun setStep(view: ALGSliderView, value: Double) { view.step = value }
  override fun setDisabled(view: ALGSliderView, value: Boolean) { view.disabled = value }
  override fun setGlassTint(view: ALGSliderView, value: Int?) { view.glassTint = value }
  override fun setRevision(view: ALGSliderView, value: Int) { /* Reconcile in the transaction below. */ }
  override fun setControlLabel(view: ALGSliderView, value: String?) { view.controlLabel = value }
  override fun setControlHint(view: ALGSliderView, value: String?) { view.controlHint = value }
  override fun setControlTestID(view: ALGSliderView, value: String?) { view.controlTestID = value }
  override fun onAfterUpdateTransaction(view: ALGSliderView) { super.onAfterUpdateTransaction(view); view.applyConfiguration() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topSliderChange" to mapOf("registrationName" to "onSliderChange"),
    "topSliderStart" to mapOf("registrationName" to "onSliderStart"),
    "topSliderComplete" to mapOf("registrationName" to "onSliderComplete"),
    "topSliderCancel" to mapOf("registrationName" to "onSliderCancel")
  )
}
