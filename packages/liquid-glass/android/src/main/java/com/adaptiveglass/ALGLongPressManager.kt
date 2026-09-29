package com.adaptiveglass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.viewmanagers.ALGLongPressManagerDelegate
import com.facebook.react.viewmanagers.ALGLongPressManagerInterface

@ReactModule(name = "ALGLongPress")
class ALGLongPressManager : ViewGroupManager<ALGLongPressView>(), ALGLongPressManagerInterface<ALGLongPressView> {
  private val delegate = ALGLongPressManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGLongPress"
  override fun createViewInstance(context: ThemedReactContext) = ALGLongPressView(context)
  override fun setMinimumDuration(view: ALGLongPressView, value: Int) { view.minimumDuration = value }
  override fun setAllowableMovement(view: ALGLongPressView, value: Float) { view.allowableMovement = value }
  override fun setDisabled(view: ALGLongPressView, value: Boolean) { view.disabled = value }
  override fun setHaptic(view: ALGLongPressView, value: String?) { view.haptic = value ?: "none" }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topLongPress" to mapOf("registrationName" to "onLongPress")
  )
}
