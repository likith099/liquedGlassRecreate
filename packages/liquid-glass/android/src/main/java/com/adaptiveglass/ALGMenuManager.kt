package com.adaptiveglass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.viewmanagers.ALGMenuManagerDelegate
import com.facebook.react.viewmanagers.ALGMenuManagerInterface

@ReactModule(name = "ALGMenu")
class ALGMenuManager : SimpleViewManager<ALGMenuView>(), ALGMenuManagerInterface<ALGMenuView> {
  private val delegate = ALGMenuManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGMenu"
  override fun createViewInstance(context: ThemedReactContext) = ALGMenuView(context)
  override fun setTitle(view: ALGMenuView, value: String?) { view.title = value ?: "" }
  override fun setItemsJSON(view: ALGMenuView, value: String?) { view.itemsJSON = value ?: "[]" }
  override fun setToolbar(view: ALGMenuView, value: Boolean) { view.toolbar = value }
  override fun setMaxVisibleItems(view: ALGMenuView, value: Int) { view.maxVisibleItems = value }
  override fun setMergingEnabled(view: ALGMenuView, value: Boolean) { /* Native Android toolbar appearance. */ }
  override fun setSystemImage(view: ALGMenuView, value: String?) { /* SF Symbols are iOS-only. */ }
  override fun setDisabled(view: ALGMenuView, value: Boolean) { view.disabled = value }
  override fun setForceFallback(view: ALGMenuView, value: Boolean) { /* Always uses the standard Android control. */ }
  override fun setGlassTint(view: ALGMenuView, value: Int?) { view.glassTint = value }
  override fun setControlLabel(view: ALGMenuView, value: String?) { view.controlLabel = value }
  override fun setControlHint(view: ALGMenuView, value: String?) { view.controlHint = value }
  override fun setControlTestID(view: ALGMenuView, value: String?) { view.controlTestID = value }
  override fun onAfterUpdateTransaction(view: ALGMenuView) { super.onAfterUpdateTransaction(view); view.applyConfiguration() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topMenuAction" to mapOf("registrationName" to "onMenuAction")
  )
}
