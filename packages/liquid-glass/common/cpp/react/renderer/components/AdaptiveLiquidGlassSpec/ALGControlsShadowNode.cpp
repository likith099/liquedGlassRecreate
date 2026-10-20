#include "ALGControlsShadowNode.h"

namespace facebook::react {

extern const char ALGControlsComponentName[] = "ALGControls";

void ALGControlsShadowNode::setMeasurer(const std::shared_ptr<const ALGControlsMeasurer> &measurer) {
  ensureUnsealed();
  measurer_ = measurer;
}

Size ALGControlsShadowNode::measureContent(
    const LayoutContext &layoutContext,
    const LayoutConstraints &layoutConstraints) const {
  if (!measurer_) {
    return layoutConstraints.clamp({44, 44});
  }
  return measurer_->measure(getSurfaceId(), getConcreteProps(), layoutContext, layoutConstraints);
}

} // namespace facebook::react
