#import "ALGScrollEdgeComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <React/RCTConversions.h>
#import <React/RCTScrollViewComponentView.h>
using namespace facebook::react;

/// A container for floating bars over a React Native ScrollView. On iOS 26 it registers with UIKit's
/// scroll-edge element container interaction, so the scroll view draws its own edge effect under
/// this container's frame. Below iOS 26 it can draw a gradient scrim instead.
@implementation ALGScrollEdgeComponentView {
  NSInteger _scrollViewTag;
  UIRectEdge _edge;
  ALGScrollEdgeEffectStyle _style;
  UIColor *_fallbackColor;
  id<UIInteraction> _interaction;
  CAGradientLayer *_scrim;
  __weak UIScrollView *_attached;
  NSInteger _attachedTag;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGScrollEdgeComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGScrollEdgeProps>();
    _scrollViewTag = -1;
    _edge = UIRectEdgeBottom;
    _style = ALGScrollEdgeEffectStyle::Automatic;
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGScrollEdgeProps>(props);
  _scrollViewTag = p.scrollViewTag;
  _edge = p.edge == ALGScrollEdgeEdge::Top ? UIRectEdgeTop : UIRectEdgeBottom;
  _style = p.effectStyle;
  _fallbackColor = RCTUIColorFromSharedColor(p.fallbackColor);
  [super updateProps:props oldProps:oldProps];
  [self attach];
}
- (UIScrollView *)targetScrollView {
  if (_scrollViewTag <= 0 || !self.window) return nil;
  // viewWithTag walks the window hierarchy; reuse the result while it is still valid.
  if (_attached.window && _attachedTag == _scrollViewTag) return _attached;
  UIView *view = [self.window viewWithTag:_scrollViewTag];
  UIScrollView *scrollView = [view isKindOfClass:RCTScrollViewComponentView.class]
    ? ((RCTScrollViewComponentView *)view).scrollView
    : ([view isKindOfClass:UIScrollView.class] ? (UIScrollView *)view : nil);
  _attached = scrollView;
  _attachedTag = _scrollViewTag;
  return scrollView;
}
- (void)attach {
  UIScrollView *scrollView = [self targetScrollView];
  if (@available(iOS 26.0, *)) {
    UIScrollEdgeElementContainerInteraction *interaction = (UIScrollEdgeElementContainerInteraction *)_interaction;
    if (!interaction) {
      interaction = [UIScrollEdgeElementContainerInteraction new];
      [self addInteraction:interaction];
      _interaction = interaction;
    }
    interaction.scrollView = scrollView;
    interaction.edge = _edge;
    UIScrollEdgeEffect *effect = _edge == UIRectEdgeTop ? scrollView.topEdgeEffect : scrollView.bottomEdgeEffect;
    switch (_style) {
      case ALGScrollEdgeEffectStyle::Soft: effect.style = UIScrollEdgeEffectStyle.softStyle; break;
      case ALGScrollEdgeEffectStyle::Hard: effect.style = UIScrollEdgeEffectStyle.hardStyle; break;
      default: effect.style = UIScrollEdgeEffectStyle.automaticStyle; break;
    }
    return;
  }
  [self updateScrim];
}
- (void)updateScrim {
  if (!_fallbackColor) { [_scrim removeFromSuperlayer]; _scrim = nil; return; }
  if (!_scrim) { _scrim = [CAGradientLayer layer]; [self.layer insertSublayer:_scrim atIndex:0]; }
  UIColor *resolved = [_fallbackColor resolvedColorWithTraitCollection:self.traitCollection];
  NSArray *colors = @[(id)[resolved colorWithAlphaComponent:0].CGColor, (id)resolved.CGColor];
  _scrim.colors = _edge == UIRectEdgeTop ? colors.reverseObjectEnumerator.allObjects : colors;
  _scrim.frame = self.bounds;
}
- (void)didMoveToWindow {
  [super didMoveToWindow];
  [self attach];
}
- (void)layoutSubviews {
  [super layoutSubviews];
  // The ScrollView may mount after this container; retry until it is found.
  [self attach];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  [self updateScrim];
}
@end
