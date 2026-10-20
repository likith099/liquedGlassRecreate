package com.adaptiveglass
import com.facebook.react.module.annotations.ReactModule
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
    "topControlAction" to mapOf("registrationName" to "onControlAction"),
    "topContentSize" to mapOf("registrationName" to "onContentSize"))
}
