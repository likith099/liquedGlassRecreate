#import <UIKit/UIKit.h>
#include <react/renderer/components/AdaptiveLiquidGlassSpec/ALGControlsMeasurer.h>
#import "AdaptiveLiquidGlass-Swift.h"

namespace facebook::react {

// Runs on React Native's layout thread. ALGControlsLayout uses only UIKit value
// APIs (fonts, symbol images, text metrics) and the same geometry as the view.
Size ALGControlsMeasurer::measure(
    SurfaceId /*surfaceId*/,
    const ALGControlsProps &props,
    const LayoutContext &layoutContext,
    const LayoutConstraints &layoutConstraints) const {
  NSString *json = [[NSString alloc] initWithBytes:props.configJSON.data() length:props.configJSON.size() encoding:NSUTF8StringEncoding] ?: @"{}";
  CGSize size = [ALGControlsLayout measure:json
                                     scale:layoutContext.pointScaleFactor
                        fontSizeMultiplier:layoutContext.fontSizeMultiplier
                                  maxWidth:layoutConstraints.maximumSize.width];
  return layoutConstraints.clamp({size.width, size.height});
}

} // namespace facebook::react
