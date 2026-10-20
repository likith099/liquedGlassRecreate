#import "ALGScrollEdgeComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <React/RCTConversions.h>
#import <React/RCTScrollViewComponentView.h>
using namespace facebook::react;

@interface ALGScrollEdgeContentView : UIView @end
@implementation ALGScrollEdgeContentView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIView *hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}
@end

/// A container for floating bars over a React Native ScrollView. On iOS 26 it registers with UIKit's
/// scroll-edge element container interaction, so the scroll view draws its own edge effect under
/// this container's frame. Below iOS 26 it can draw a gradient scrim instead.
@implementation ALGScrollEdgeComponentView {
  UIView *_content;
  UIImageView *_edgeElement;
  BOOL _attaching;
  NSInteger _scrollViewTag;
  UIRectEdge _edge;
  ALGScrollEdgeEffectStyle _style;
  UIColor *_fallbackColor;
  ALGScrollEdgeFallbackMode _fallbackMode;
  UIVisualEffectView *_fallbackBlur;
  UIView *_solid;
  __weak UIScrollEdgeEffect *_styledEffect;
  UIScrollEdgeEffectStyle *_previousStyle;
  UIScrollEdgeEffectStyle *_appliedStyle;
  id<UIInteraction> _interaction;
  CAGradientLayer *_scrim;
  __weak UIScrollView *_attached;
  NSInteger _attachedTag;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGScrollEdgeComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGScrollEdgeProps>();
    _content = [ALGScrollEdgeContentView new]; [self addSubview:_content];
    _scrollViewTag = -1;
    _edge = UIRectEdgeBottom;
    _style = ALGScrollEdgeEffectStyle::Automatic;
    _fallbackMode = ALGScrollEdgeFallbackMode::Gradient;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attach)
      name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
  }
  return self;
}
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [_content insertSubview:child atIndex:index];
}
- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [child removeFromSuperview];
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGScrollEdgeProps>(props);
  _scrollViewTag = p.scrollViewTag;
  _edge = p.edge == ALGScrollEdgeEdge::Top ? UIRectEdgeTop : UIRectEdgeBottom;
  _style = p.effectStyle;
  _fallbackMode = p.fallbackMode;
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
- (void)restoreEdgeStyle {
  if (@available(iOS 26.0, *)) {
    if (_styledEffect.style == _appliedStyle && _previousStyle) _styledEffect.style = _previousStyle;
    _styledEffect = nil; _previousStyle = nil; _appliedStyle = nil;
  }
}
- (void)attach {
  if (_attaching) return;
  _attaching = YES;
  @try {
  UIScrollView *scrollView = [self targetScrollView];
  if (@available(iOS 26.0, *)) {
    UIScrollEdgeElementContainerInteraction *interaction = (UIScrollEdgeElementContainerInteraction *)_interaction;
    if (!UIAccessibilityIsReduceTransparencyEnabled() && self.window) {
      // RN text is not UILabel. A clear image supplies a native edge element
      // spanning the actual header bounds, letting UIKit own all blur/shading.
      if ((_style == ALGScrollEdgeEffectStyle::Progressive || _style == ALGScrollEdgeEffectStyle::ProgressiveHard) && !_edgeElement) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
        _edgeElement = [[UIImageView alloc] initWithImage:[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {}]];
        _edgeElement.userInteractionEnabled = NO;
        _edgeElement.isAccessibilityElement = NO;
        [self addSubview:_edgeElement];
      }
      if (_style != ALGScrollEdgeEffectStyle::Progressive && _style != ALGScrollEdgeEffectStyle::ProgressiveHard) { [_edgeElement removeFromSuperview]; _edgeElement = nil; }
      _edgeElement.frame = self.bounds;
      if (!interaction) {
        interaction = [UIScrollEdgeElementContainerInteraction new];
        interaction.scrollView = scrollView; interaction.edge = _edge;
        _interaction = interaction; [self addInteraction:interaction];
      } else { interaction.scrollView = scrollView; interaction.edge = _edge; }
      UIScrollEdgeEffect *effect = _edge == UIRectEdgeTop ? scrollView.topEdgeEffect : scrollView.bottomEdgeEffect;
      if (_styledEffect != effect) {
        [self restoreEdgeStyle]; _styledEffect = effect; _previousStyle = effect.style;
      }
      switch (_style) {
        case ALGScrollEdgeEffectStyle::Progressive:
        case ALGScrollEdgeEffectStyle::Soft: _appliedStyle = UIScrollEdgeEffectStyle.softStyle; break;
        case ALGScrollEdgeEffectStyle::ProgressiveHard:
        case ALGScrollEdgeEffectStyle::Hard: _appliedStyle = UIScrollEdgeEffectStyle.hardStyle; break;
        default: _appliedStyle = UIScrollEdgeEffectStyle.automaticStyle; break;
      }
      effect.style = _appliedStyle;
      [_scrim removeFromSuperlayer]; _scrim = nil;
      [_solid removeFromSuperview]; _solid = nil;
      [_fallbackBlur removeFromSuperview]; _fallbackBlur = nil;
      return;
    }
    interaction.scrollView = nil;
    if (interaction) [self removeInteraction:interaction];
    _interaction = nil; [self restoreEdgeStyle];
  }
  [_edgeElement removeFromSuperview]; _edgeElement = nil;
  [self updateScrim];
  } @finally { _attaching = NO; }
}
- (void)updateScrim {
  UIColor *fill = _fallbackColor ?: UIColor.systemBackgroundColor;
  BOOL solid = (_fallbackMode == ALGScrollEdgeFallbackMode::Solid || UIAccessibilityIsReduceTransparencyEnabled());
  BOOL blur = _fallbackMode == ALGScrollEdgeFallbackMode::Blur && !solid;
  if (solid || blur) {
    [_scrim removeFromSuperlayer]; _scrim = nil;
    if (!_solid) { _solid = [UIView new]; _solid.userInteractionEnabled = NO; [self insertSubview:_solid atIndex:0]; }
    _solid.backgroundColor = solid ? [fill colorWithAlphaComponent:1] : [fill colorWithAlphaComponent:0.15];
    _solid.frame = self.bounds;
    if (blur) {
      if (!_fallbackBlur) {
        _fallbackBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
        _fallbackBlur.userInteractionEnabled = NO; [self insertSubview:_fallbackBlur atIndex:0];
      }
      _fallbackBlur.frame = self.bounds;

    } else { [_fallbackBlur removeFromSuperview]; _fallbackBlur = nil; }
    return;
  }
  [_solid removeFromSuperview]; _solid = nil; [_fallbackBlur removeFromSuperview]; _fallbackBlur = nil;
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
  _content.frame = self.bounds;
  // The ScrollView may mount after this container; retry until it is found.
  [self attach];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  [self attach];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [self restoreEdgeStyle]; }
+ (BOOL)shouldBeRecycled { return NO; }
@end
