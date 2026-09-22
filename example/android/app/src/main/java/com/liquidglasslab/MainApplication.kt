package com.liquidglasslab

import android.app.Application
import android.view.View
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost
import com.facebook.react.modules.i18nmanager.I18nUtil

class MainApplication : Application(), ReactApplication {

  override val reactHost: ReactHost by lazy {
    getDefaultReactHost(
      context = applicationContext,
      packageList =
        PackageList(this).packages.apply {
          // Packages that cannot be autolinked yet can be added manually here, for example:
          // add(MyReactNativePackage())
        },
    )
  }

  override fun onCreate() {
    super.onCreate()
    // RN 0.87's locale detection reads availableLocales[0], not the active locale.
    // Align this demo's React layout with Android's actual app configuration before
    // the host starts. The package never changes a consumer's global RTL settings.
    I18nUtil.instance.forceRTL(this, resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL)
    loadReactNative(this)
  }
}
