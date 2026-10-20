#pragma once

#include <react/renderer/components/AdaptiveLiquidGlassSpec/ALGControlsMeasurer.h>
#include <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#include <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

JSI_EXPORT extern const char ALGControlsComponentName[];

/*
 * A measurable leaf: Yoga asks the platform for the control's intrinsic size, so
 * the first commit already has the right frame and a content change resizes
 * without waiting for JavaScript.
 */
class ALGControlsShadowNode final
    : public ConcreteViewShadowNode<ALGControlsComponentName, ALGControlsProps, ALGControlsEventEmitter> {
 public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  void setMeasurer(const std::shared_ptr<const ALGControlsMeasurer> &measurer);

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

 private:
  std::shared_ptr<const ALGControlsMeasurer> measurer_;
};

} // namespace facebook::react
