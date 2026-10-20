#import "ALGNavigationComponentView.h"
#import <React/UIView+React.h>
#import <React/RCTScrollViewComponentView.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/RCTComponentViewHelpers.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@interface ALGNavigationComponentView () <RCTALGNavigationViewProtocol> @end
@implementation ALGNavigationComponentView {
  ALGNavigationView *_host;
  NSInteger _scrollTag;
  __weak UIScrollView *_scroll;
  NSInteger _resolvedTag;
  __weak RCTScrollViewComponentView *_scrollComponent;
  NSInteger _bindAttempts;
  BOOL _bindRetryScheduled;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGNavigationComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGNavigationProps>();
    _scrollTag = -1;
    _host = [[ALGNavigationView alloc] initWithFrame:CGRectZero]; self.contentView = _host;
    __weak ALGNavigationComponentView *weakSelf = self;
    _host.onAction = ^(NSString *identifier, NSString *action) {
      ALGNavigationComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGNavigationEventEmitter>(self->_eventEmitter)->onNavigationAction({std::string(identifier.UTF8String), std::string(action.UTF8String)});
    };
    _host.onInsets = ^(double top, double bottom, double width) {
      ALGNavigationComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGNavigationEventEmitter>(self->_eventEmitter)->onNavigationInsets({top, bottom, width});
    };
    _host.onSearch = ^(NSString *kind, NSString *text, NSInteger count) {
      ALGNavigationComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGNavigationEventEmitter>(self->_eventEmitter)->onNavigationSearch({std::string(kind.UTF8String), std::string(text.UTF8String), (int)count});
    };
  } return self;
}
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [_host setReactChild:child at:index]; [self setNeedsLayout];
}
- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index { [_host removeReactChild:child]; }
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGNavigationProps>(props);
  if (_scrollTag != p.scrollViewTag) _bindAttempts = 0;
  _scrollTag = p.scrollViewTag;
  [_host configure:@(p.configJSON.c_str())];
  [super updateProps:props oldProps:oldProps]; [self bindScroll];
  // Fabric can deliver the tag before the scroll child is mounted in the window.
  // Bind after the mounting transaction, before the first user scroll.
  __weak ALGNavigationComponentView *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf bindScroll]; });
}
- (void)bindScroll {
  UIScrollView *scroll = _scroll;
  if (!scroll.window || _resolvedTag != _scrollTag) {
    UIView *view = _scrollTag > 0 ? [self.window viewWithTag:_scrollTag] : nil;
    scroll = [view isKindOfClass:RCTScrollViewComponentView.class] ? ((RCTScrollViewComponentView *)view).scrollView
      : ([view isKindOfClass:UIScrollView.class] ? (UIScrollView *)view : nil);
    // The navigation host owns this viewport; never borrow a different screen's list.
    if (scroll && ![scroll isDescendantOfView:_host.reactContentView]) scroll = nil;
    RCTScrollViewComponentView *component = [view isKindOfClass:RCTScrollViewComponentView.class] ? (RCTScrollViewComponentView *)view : nil;
    if (_scrollComponent != component) {
      [_scrollComponent.scrollViewDelegateSplitter removeDelegate:_host];
      _scrollComponent = component;
      if (scroll) [component.scrollViewDelegateSplitter addDelegate:_host];
    }
    _scroll = scroll; _resolvedTag = _scrollTag;
  }
  [_host bindScrollView:scroll];
  // The list can mount after every layout/props pass of this view. Without a retry
  // the title row and edge stay unbound until an unrelated prop change.
  if (scroll) { _bindAttempts = 0; return; }
  if (_scrollTag <= 0 || !self.window || _bindRetryScheduled || _bindAttempts >= 40) return;
  _bindAttempts += 1; _bindRetryScheduled = YES;
  __weak ALGNavigationComponentView *weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    ALGNavigationComponentView *strongSelf = weakSelf;
    if (!strongSelf) return;
    strongSelf->_bindRetryScheduled = NO; [strongSelf bindScroll];
  });
}
- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) { [_host attachTo:[self reactViewController]]; [self bindScroll]; }
  else { [_host detach]; }
}
- (void)layoutSubviews {
  [super layoutSubviews];
  if (self.window) { [_host attachTo:[self reactViewController]]; [self bindScroll]; }
}
- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args { RCTALGNavigationHandleCommand(self, commandName, args); }
- (void)scrollToTop:(BOOL)animated { [_host scrollToTop:animated]; }
- (void)focusSearch { [_host focusSearch]; }
- (void)dismissSearch { [_host dismissSearch]; }
- (void)dealloc { [_scrollComponent.scrollViewDelegateSplitter removeDelegate:_host]; }
+ (BOOL)shouldBeRecycled { return NO; }
@end
