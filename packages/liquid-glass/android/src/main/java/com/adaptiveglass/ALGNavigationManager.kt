package com.adaptiveglass
import android.view.View
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.viewmanagers.ALGNavigationManagerDelegate
import com.facebook.react.viewmanagers.ALGNavigationManagerInterface
@ReactModule(name = "ALGNavigation")
class ALGNavigationManager : ViewGroupManager<ALGNavigationView>(), ALGNavigationManagerInterface<ALGNavigationView> {
  private val delegate = ALGNavigationManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGNavigation"
  override fun createViewInstance(context: ThemedReactContext) = ALGNavigationView(context)
  override fun setConfigJSON(view: ALGNavigationView, value: String?) { view.configure(value ?: "{}") }
  override fun setScrollViewTag(view: ALGNavigationView, value: Int) { view.scrollTag = value }
  override fun addView(parent: ALGNavigationView, child: View, index: Int) { parent.mount(child, index) }
  override fun getChildCount(parent: ALGNavigationView) = parent.reactChildren.size
  override fun getChildAt(parent: ALGNavigationView, index: Int): View = parent.reactChildren[index]
  override fun removeViewAt(parent: ALGNavigationView, index: Int) { parent.unmount(index) }
  override fun needsCustomLayoutForChildren() = true
  override fun scrollToTop(view: ALGNavigationView, animated: Boolean) { view.scrollToTop(animated) }
  override fun focusSearch(view: ALGNavigationView) { view.focusSearch() }
  override fun dismissSearch(view: ALGNavigationView) { view.dismissSearch() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
    "topNavigationAction" to mapOf("registrationName" to "onNavigationAction"),
    "topNavigationSearch" to mapOf("registrationName" to "onNavigationSearch"),
    "topNavigationInsets" to mapOf("registrationName" to "onNavigationInsets"))
}
