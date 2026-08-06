#import "StoreLinkButton.h"

// The chevron's tip sits this far in from the trailing edge.
static const CGFloat kChevronTrailingInset = 2.0;
// Each arm runs this far back and this far up or down from the tip.
static const CGFloat kChevronArmLength = 5.0;

static const CGFloat kChevronLineWidth = 3.0;
// The shadow is taken from the title label's offset, with no blur of its own.
static const CGFloat kChevronShadowBlur = 0.0;

@implementation StoreLinkButton

#pragma mark - State

/** @ghidraAddress 0x1bdae4 */
- (void)setHighlighted:(BOOL)highlighted {
    // The exclusive-or against the current value is a changed-test: the redraw below happens only
    // when the state actually flips, not on every set.
    BOOL changed = [super isHighlighted] ^ highlighted;
    [super setHighlighted:highlighted];
    if (changed) {
        [self setNeedsDisplay];
    }
}

/** @ghidraAddress 0x1bdb70 */
- (void)setSelected:(BOOL)selected {
    BOOL changed = [super isSelected] ^ selected;
    [super setSelected:selected];
    if (changed) {
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

/** @ghidraAddress 0x1bdbfc */
- (void)drawRect:(CGRect)rect {
    // Yes, rect is ignored, and the size comes from frame rather than bounds. Only the size is
    // read, so the two agree here, but the binary asks for frame.
    CGFloat tipX = self.frame.size.width - kChevronTrailingInset;
    CGFloat midY = self.frame.size.height / 2;

    // A plain ">" : back and up, forward to the tip, back and down.
    UIBezierPath *path = UIBezierPath.bezierPath;
    [path moveToPoint:CGPointMake(tipX - kChevronArmLength, midY - kChevronArmLength)];
    [path addLineToPoint:CGPointMake(tipX, midY)];
    [path addLineToPoint:CGPointMake(tipX - kChevronArmLength, midY + kChevronArmLength)];
    path.lineWidth = kChevronLineWidth;
    path.lineJoinStyle = kCGLineJoinMiter;
    path.lineCapStyle = kCGLineCapButt;

    // The chevron borrows the title's shadow and colour for whatever state the button is in, which
    // is what makes the two setters above worth overriding.
    CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(),
                                self.titleLabel.shadowOffset,
                                kChevronShadowBlur,
                                self.currentTitleShadowColor.CGColor);
    [self.currentTitleColor setStroke];
    [path stroke];
}

@end
