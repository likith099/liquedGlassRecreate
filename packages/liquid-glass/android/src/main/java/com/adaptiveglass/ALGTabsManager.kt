package com.adaptiveglass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.viewmanagers.ALGTabsManagerDelegate
import com.facebook.react.viewmanagers.ALGTabsManagerInterface

@ReactModule(name = "ALGTabs")
class ALGTabsManager : SimpleViewManager<ALGTabsView>(), ALGTabsManagerInterface<ALGTabsView> {
  private val delegate = ALGTabsManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGTabs"
  override fun createViewInstance(context: ThemedReactContext) = ALGTabsView(context)
  override fun setItemsJSON(view: ALGTabsView, value: String?) { view.itemsJSON = value ?: "[]" }
  override fun setSelectedValue(view: ALGTabsView, value: String?) { view.selectedValue = value ?: "" }
  override fun setSelectionRevision(view: ALGTabsView, value: Int) { /* Reconcile in the transaction, including rejected taps. */ }
  override fun setDisabled(view: ALGTabsView, value: Boolean) { view.disabled = value }
  override fun setGlassTint(view: ALGTabsView, value: Int?) { view.glassTint = value }
  override fun setControlTestID(view: ALGTabsView, value: String?) { view.controlTestID = value }
  override fun onAfterUpdateTransaction(view: ALGTabsView) { super.onAfterUpdateTransaction(view); view.applyConfiguration() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topSelectionChange" to mapOf("registrationName" to "onSelectionChange"))
}
