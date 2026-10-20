#pragma once

#include <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>
#include <react/renderer/graphics/Size.h>
#include <react/utils/ContextContainer.h>

namespace facebook::react {

/*
 * Measures ALGControls (icon groups, pill bars, morph buttons, header slots) on
 * React Native's layout thread, so Yoga has the native size in the same commit.
 * iOS: ALGControlsMeasurer.mm (UIKit value APIs). Android: the ViewManager's measure().
 */
class ALGControlsMeasurer final {
 public:
  explicit ALGControlsMeasurer(std::shared_ptr<const ContextContainer> contextContainer)
      : contextContainer_(std::move(contextContainer)) {}

  Size measure(
      SurfaceId surfaceId,
      const ALGControlsProps &props,
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const;

 private:
  std::shared_ptr<const ContextContainer> contextContainer_;
};

} // namespace facebook::react
