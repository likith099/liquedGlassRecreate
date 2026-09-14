#import "ALGSurfaceComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"

using namespace facebook::react;

@implementation ALGSurfaceComponentView {
  ALGSurfaceView *_glass;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ALGSurfaceComponentDescriptor>();
}
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGSurfaceProps>();
    _glass = [[ALGSurfaceView alloc] initWithFrame:CGRectZero];
    self.contentView = _glass;
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGSurfaceProps>(props);
  NSString *material = p.material == ALGSurfaceMaterial::Clear ? @"clear" : p.material == ALGSurfaceMaterial::None ? @"none" : @"regular";
  NSString *scheme = p.colorScheme == ALGSurfaceColorScheme::Dark ? @"dark" : p.colorScheme == ALGSurfaceColorScheme::Light ? @"light" : @"system";
  [_glass configure:material interactive:p.interactive tint:RCTUIColorFromSharedColor(p.glassTint)
             radius:p.glassRadius container:p.container mergingEnabled:p.mergingEnabled spacing:p.spacing duration:p.animationDuration scheme:scheme];
  [super updateProps:props oldProps:oldProps];
}
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [_glass.reactContentView insertSubview:child atIndex:index];
}
- (void)layoutSubviews {
  [super layoutSubviews];
  // Fabric's default contentView frame excludes padding. React children already
  // carry Yoga's padding offsets, so the material must occupy the full bounds.
  _glass.frame = self.bounds;
}
- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [child removeFromSuperview];
}
// UIKit effects retain state; a fresh instance also avoids stale effects on remount.
+ (BOOL)shouldBeRecycled { return NO; }
@end
