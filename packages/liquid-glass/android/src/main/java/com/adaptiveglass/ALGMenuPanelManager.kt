package com.adaptiveglass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.viewmanagers.ALGMenuPanelManagerDelegate
import com.facebook.react.viewmanagers.ALGMenuPanelManagerInterface

@ReactModule(name = "ALGMenuPanel")
class ALGMenuPanelManager : SimpleViewManager<ALGMenuPanelView>(), ALGMenuPanelManagerInterface<ALGMenuPanelView> {
  private val delegate = ALGMenuPanelManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGMenuPanel"
  override fun createViewInstance(context: ThemedReactContext) = ALGMenuPanelView(context)
  override fun setItemsJSON(view: ALGMenuPanelView, value: String?) { view.itemsJSON = value ?: "[]" }
  override fun setFontScale(view: ALGMenuPanelView, value: Float) { view.fontScale = value }
  override fun setColorScheme(view: ALGMenuPanelView, value: String?) { view.colorScheme = value ?: "system" }
  override fun setDisabled(view: ALGMenuPanelView, value: Boolean) { view.disabled = value }
  override fun setAppearFrom(view: ALGMenuPanelView, value: String?) { view.appearFrom = value ?: "none" }
  override fun setAutoFocus(view: ALGMenuPanelView, value: Boolean) { view.autoFocus = value }
  override fun setMenuModal(view: ALGMenuPanelView, value: Boolean) { view.menuModal = value }
  override fun setMenuStyleJSON(view: ALGMenuPanelView, value: String?) { view.menuStyleJSON = value ?: "" }
  override fun setControlTestID(view: ALGMenuPanelView, value: String?) { view.controlTestID = value }
  override fun dismiss(view: ALGMenuPanelView) { view.dismiss() }
  override fun onAfterUpdateTransaction(view: ALGMenuPanelView) { super.onAfterUpdateTransaction(view); view.applyConfiguration() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topMenuAction" to mapOf("registrationName" to "onMenuAction"),
    "topCancelTouch" to mapOf("registrationName" to "onCancelTouch"),
    "topDismissed" to mapOf("registrationName" to "onDismissed"),
    "topRequestClose" to mapOf("registrationName" to "onRequestClose")
  )
}
