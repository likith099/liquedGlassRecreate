package com.adaptiveglass
import android.view.View
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.viewmanagers.ALGPresenceManagerDelegate
import com.facebook.react.viewmanagers.ALGPresenceManagerInterface
import com.facebook.react.views.view.ReactViewGroup
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.facebook.react.bridge.Arguments
private class PresenceEvent(surface: Int, tag: Int) : Event<PresenceEvent>(surface, tag) {
  override fun getEventName() = "topExited"
  override fun canCoalesce() = false
  override fun getEventData() = Arguments.createMap()
}
class ALGPresenceView(val reactContext: ThemedReactContext) : ReactViewGroup(reactContext) {
  var shown = true; var transition = "materialize"; private var applied: Boolean? = null; private var generation = 0
  fun apply() {
    if (applied == shown) return
    val first = applied == null; applied = shown; val current = ++generation; animate().cancel()
    if (first && shown) { scaleX = 0.5f; scaleY = 0.5f; alpha = 0f }
    val done = Runnable { if (current == generation && !shown) UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)?.dispatchEvent(PresenceEvent(UIManagerHelper.getSurfaceId(reactContext), id)) }
    val duration = if (transition == "none" || !isAttachedToWindow || !(android.os.Build.VERSION.SDK_INT < 26 || android.animation.ValueAnimator.areAnimatorsEnabled())) 0L else if (shown) 350L else 120L
    animate().scaleX(if (shown) 1f else 0.5f).scaleY(if (shown) 1f else 0.5f).alpha(if (shown) 1f else 0f).setDuration(duration).withEndAction(done).start()
  }
  override fun onAttachedToWindow() { super.onAttachedToWindow(); apply() }
  override fun onDetachedFromWindow() { animate().cancel(); super.onDetachedFromWindow() }
}
@ReactModule(name = "ALGPresence")
class ALGPresenceManager : ViewGroupManager<ALGPresenceView>(), ALGPresenceManagerInterface<ALGPresenceView> {
  private val delegate = ALGPresenceManagerDelegate(this)
  override fun getDelegate() = delegate
  override fun getName() = "ALGPresence"
  override fun createViewInstance(context: ThemedReactContext) = ALGPresenceView(context)
  override fun setVisible(view: ALGPresenceView, value: Boolean) { view.shown = value }
  override fun setTransition(view: ALGPresenceView, value: String?) { view.transition = value ?: "materialize" }
  override fun onAfterUpdateTransaction(view: ALGPresenceView) { super.onAfterUpdateTransaction(view); if (view.isAttachedToWindow) view.apply() }
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf("topExited" to mapOf("registrationName" to "onExited"))
}
