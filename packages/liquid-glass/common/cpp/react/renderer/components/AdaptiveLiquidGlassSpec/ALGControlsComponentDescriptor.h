#pragma once

#include <react/renderer/components/AdaptiveLiquidGlassSpec/ALGControlsMeasurer.h>
#include <react/renderer/components/AdaptiveLiquidGlassSpec/ALGControlsShadowNode.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook::react {

class ALGControlsComponentDescriptor final : public ConcreteComponentDescriptor<ALGControlsShadowNode> {
 public:
  explicit ALGControlsComponentDescriptor(const ComponentDescriptorParameters &parameters)
      : ConcreteComponentDescriptor(parameters),
        measurer_(std::make_shared<const ALGControlsMeasurer>(contextContainer_)) {}

  void adopt(ShadowNode &shadowNode) const override {
    ConcreteComponentDescriptor::adopt(shadowNode);
    static_cast<ALGControlsShadowNode &>(shadowNode).setMeasurer(measurer_);
  }

 private:
  const std::shared_ptr<const ALGControlsMeasurer> measurer_;
};

} // namespace facebook::react
