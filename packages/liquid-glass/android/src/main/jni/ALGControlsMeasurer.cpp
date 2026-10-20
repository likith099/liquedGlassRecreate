#include <react/renderer/components/AdaptiveLiquidGlassSpec/ALGControlsMeasurer.h>

#include <fbjni/fbjni.h>
#include <folly/dynamic.h>
#include <react/jni/ReadableNativeMap.h>
#include <react/renderer/core/conversions.h>

using namespace facebook::jni;

namespace facebook::react {

// Delegates to ALGControlsManager.measure() through FabricUIManager, the same path
// React Native uses for its own measured Android components.
Size ALGControlsMeasurer::measure(
    SurfaceId surfaceId,
    const ALGControlsProps &props,
    const LayoutContext & /*layoutContext*/,
    const LayoutConstraints &layoutConstraints) const {
  const jni::global_ref<jobject> &fabricUIManager =
      contextContainer_->at<jni::global_ref<jobject>>("FabricUIManager");
  static auto measure = jni::findClassStatic("com/facebook/react/fabric/FabricUIManager")
                            ->getMethod<jlong(
                                jint,
                                jstring,
                                ReadableMap::javaobject,
                                ReadableMap::javaobject,
                                ReadableMap::javaobject,
                                jfloat,
                                jfloat,
                                jfloat,
                                jfloat)>("measure");
  auto minimumSize = layoutConstraints.minimumSize;
  auto maximumSize = layoutConstraints.maximumSize;
  local_ref<JString> componentName = make_jstring("ALGControls");
  folly::dynamic serialized = folly::dynamic::object("configJSON", props.configJSON);
  local_ref<ReadableNativeMap::javaobject> propsRNM = ReadableNativeMap::newObjectCxxArgs(serialized);
  local_ref<ReadableMap::javaobject> propsRM = make_local(reinterpret_cast<ReadableMap::javaobject>(propsRNM.get()));
  return yogaMeassureToSize(measure(
      fabricUIManager,
      surfaceId,
      componentName.get(),
      nullptr,
      propsRM.get(),
      nullptr,
      minimumSize.width,
      maximumSize.width,
      minimumSize.height,
      maximumSize.height));
}

} // namespace facebook::react
