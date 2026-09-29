#import "ALGSymbolComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <React/RCTConversions.h>
using namespace facebook::react;

/// An SF Symbol for rows that React lays out itself, such as GlassMenuPanel. It is decorative:
/// the row carries the accessible title.
@implementation ALGSymbolComponentView {
  UIImageView *_imageView;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGSymbolComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGSymbolProps>();
    _imageView = [UIImageView new];
    _imageView.contentMode = UIViewContentModeCenter;
    self.contentView = _imageView;
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGSymbolProps>(props);
  UIImageSymbolWeight weight = UIImageSymbolWeightRegular;
  if (p.weight == ALGSymbolWeight::Medium) weight = UIImageSymbolWeightMedium;
  if (p.weight == ALGSymbolWeight::Semibold) weight = UIImageSymbolWeightSemibold;
  UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:p.pointSize weight:weight];
  _imageView.image = [UIImage systemImageNamed:@(p.systemImage.c_str()) withConfiguration:configuration];
  _imageView.tintColor = RCTUIColorFromSharedColor(p.tint) ?: UIColor.labelColor;
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
