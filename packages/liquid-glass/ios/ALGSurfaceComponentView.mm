#import "ALGSurfaceComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"

using namespace facebook::react;

@implementation ALGSurfaceComponentView {
  ALGSurfaceView *_glass;
  NSMutableDictionary<NSString *, UIView *> *_departing;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ALGSurfaceComponentDescriptor>();
}
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _departing = [NSMutableDictionary new];
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
  _glass.backgroundExtension = p.backgroundExtension;
  _glass.materialize = p.transition == ALGSurfaceTransition::Materialize;
  [_glass configure:material interactive:p.interactive tint:RCTUIColorFromSharedColor(p.glassTint)
             radius:p.glassRadius container:p.container mergingEnabled:p.mergingEnabled spacing:p.spacing duration:p.animationDuration scheme:scheme];
  [super updateProps:props oldProps:oldProps];
}
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  NSString *identity = [child isKindOfClass:RCTViewComponentView.class] ? ((RCTViewComponentView *)child).nativeId : nil;
  UIView *previous = identity ? _departing[identity] : nil;
  [_glass.reactContentView insertSubview:child atIndex:MIN(index, _glass.reactContentView.subviews.count)];
  if (previous) {
    CGRect origin = previous.frame;
    [_departing removeObjectForKey:identity];
    dispatch_async(dispatch_get_main_queue(), ^{
      CGRect target = child.frame;
      [previous removeFromSuperview];
      if (!child.window || UIAccessibilityIsReduceMotionEnabled()) return;
      child.frame = origin;
      [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{ child.frame = target; } completion:nil];
    });
  }
}
- (void)layoutSubviews {
  [super layoutSubviews];
  // Fabric's default contentView frame excludes padding. React children already
  // carry Yoga's padding offsets, so the material must occupy the full bounds.
  _glass.frame = self.bounds;
}
- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  NSString *identity = [child isKindOfClass:RCTViewComponentView.class] ? ((RCTViewComponentView *)child).nativeId : nil;
  if ([identity hasPrefix:@"alg-glass-"] && child.window) {
    _departing[identity] = child;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self->_departing[identity] == child) { [self->_departing removeObjectForKey:identity]; [child removeFromSuperview]; }
    });
  } else [child removeFromSuperview];
}
// UIKit effects retain state; a fresh instance also avoids stale effects on remount.
+ (BOOL)shouldBeRecycled { return NO; }
@end
