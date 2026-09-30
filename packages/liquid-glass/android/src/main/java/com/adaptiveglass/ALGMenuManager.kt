package com.adaptiveglass

import com.facebook.react.module.annotations.ReactModule
import android.view.View
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.viewmanagers.ALGMenuManagerDelegate
import com.facebook.react.viewmanagers.ALGMenuManagerInterface

@ReactModule(name = "ALGMenu")
class ALGMenuManager : ViewGroupManager<ALGMenuView>(), ALGMenuManagerInterface<ALGMenuView> {
  private val delegate = ALGMenuManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGMenu"
  override fun createViewInstance(context: ThemedReactContext) = ALGMenuView(context)
  override fun addView(parent: ALGMenuView, child: View, index: Int) { parent.reactContent.addView(child, index) }
  override fun getChildCount(parent: ALGMenuView) = parent.reactContent.childCount
  override fun getChildAt(parent: ALGMenuView, index: Int): View = parent.reactContent.getChildAt(index)
  override fun removeViewAt(parent: ALGMenuView, index: Int) { parent.reactContent.removeViewAt(index) }
  override fun needsCustomLayoutForChildren() = false
  override fun setContextMenu(view: ALGMenuView, value: Boolean) { view.contextMenu = value }
  override fun setPreviewCornerRadius(view: ALGMenuView, value: Float) { /* iOS preview outline only. */ }
  override fun setMenuPlacement(view: ALGMenuView, value: String?) { view.menuPlacement = value ?: "system" }
  override fun setPreviewCornerTopLeft(view: ALGMenuView, value: Float) { /* iOS preview outline only. */ }
  override fun setPreviewCornerTopRight(view: ALGMenuView, value: Float) { /* iOS preview outline only. */ }
  override fun setPreviewCornerBottomLeft(view: ALGMenuView, value: Float) { /* iOS preview outline only. */ }
  override fun setPreviewCornerBottomRight(view: ALGMenuView, value: Float) { /* iOS preview outline only. */ }
  override fun setTitle(view: ALGMenuView, value: String?) { view.title = value ?: "" }
  override fun setItemsJSON(view: ALGMenuView, value: String?) { view.itemsJSON = value ?: "[]" }
  override fun setToolbar(view: ALGMenuView, value: Boolean) { view.toolbar = value }
  override fun setMaxVisibleItems(view: ALGMenuView, value: Int) { view.maxVisibleItems = value }
  override fun setMergingEnabled(view: ALGMenuView, value: Boolean) { /* Native Android toolbar appearance. */ }
  override fun setSystemImage(view: ALGMenuView, value: String?) { /* SF Symbols are iOS-only. */ }
  override fun setIconMode(view: ALGMenuView, value: Boolean) { view.iconMode = value }
  override fun setMenuAnchor(view: ALGMenuView, value: Boolean) { view.menuAnchor = value }
  override fun setSymbolPointSize(view: ALGMenuView, value: Float) { /* The Android drawable keeps its size. */ }
  override fun setColorScheme(view: ALGMenuView, value: String?) { view.colorScheme = value ?: "system" }
  override fun setAndroidIcon(view: ALGMenuView, value: String?) { view.androidIcon = value ?: "" }
  override fun setMenuStyleJSON(view: ALGMenuView, value: String?) { view.menuStyleJSON = value ?: "" }
  override fun setIconVariant(view: ALGMenuView, value: String?) { view.iconProminent = value == "prominent" }
  override fun open(view: ALGMenuView) { view.openMenu() }
  override fun setDisabled(view: ALGMenuView, value: Boolean) { view.disabled = value }
  override fun setForceFallback(view: ALGMenuView, value: Boolean) { /* Always uses the standard Android control. */ }
  override fun setGlassTint(view: ALGMenuView, value: Int?) { view.glassTint = value }
  override fun setControlLabel(view: ALGMenuView, value: String?) { view.controlLabel = value }
  override fun setControlHint(view: ALGMenuView, value: String?) { view.controlHint = value }
  override fun setControlTestID(view: ALGMenuView, value: String?) { view.controlTestID = value }
  override fun onAfterUpdateTransaction(view: ALGMenuView) { super.onAfterUpdateTransaction(view); view.applyConfiguration() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topMenuAction" to mapOf("registrationName" to "onMenuAction"),
    "topButtonPress" to mapOf("registrationName" to "onButtonPress"),
    "topMenuOpen" to mapOf("registrationName" to "onMenuOpen"),
    "topMenuClose" to mapOf("registrationName" to "onMenuClose")
  )
}
