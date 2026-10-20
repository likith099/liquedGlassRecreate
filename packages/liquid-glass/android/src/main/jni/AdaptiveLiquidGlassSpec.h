#pragma once

#include <ReactCommon/JavaTurboModule.h>
#include <ReactCommon/TurboModule.h>
#include <jsi/jsi.h>

/*
 * Replaces the codegen header of the same name (via include order in CMakeLists.txt)
 * so the autolinked registry sees the hand-written ALGControls descriptor.
 */
#include <react/renderer/components/AdaptiveLiquidGlassSpec/ALGControlsComponentDescriptor.h>
#include <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>

namespace facebook::react {

JSI_EXPORT
std::shared_ptr<TurboModule> AdaptiveLiquidGlassSpec_ModuleProvider(const std::string &moduleName, const JavaTurboModule::InitParams &params);

} // namespace facebook::react
