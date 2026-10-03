#import "RPClassicTheme.h"
UIColor *RPClassicBlue(void) { return [UIColor colorWithRed:0.25 green:0.34 blue:0.46 alpha:1]; }
static void RPGradient(CGContextRef context, CGRect rect, UIColor *top, UIColor *bottom) {
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    NSArray *colors=@[(id)top.CGColor,(id)bottom.CGColor];
    CGGradientRef gradient=CGGradientCreateWithColors(space,(__bridge CFArrayRef)colors,NULL);
    CGContextDrawLinearGradient(context,gradient,CGPointMake(0,CGRectGetMinY(rect)),CGPointMake(0,CGRectGetMaxY(rect)),0);
    CGGradientRelease(gradient); CGColorSpaceRelease(space);
}
NSArray *RPBubbleThemeNames(void) { return @[@"Classic", @"Blue", @"Pink", @"Purple", @"Amber", @"Rainbow"]; }
NSString *RPBubbleThemeName(void) {
    NSString *name=[[NSUserDefaults standardUserDefaults] stringForKey:@"bubbleTheme"];
    return [RPBubbleThemeNames() containsObject:name ?: @""] ? name : @"Classic";
}
void RPSetBubbleTheme(NSString *name) {
    if([RPBubbleThemeNames() containsObject:name]) [[NSUserDefaults standardUserDefaults] setObject:name forKey:@"bubbleTheme"];
}
@implementation RPClassicBubbleView
- (id)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor clearColor]; self.opaque=NO;
        self.contentMode=UIViewContentModeRedraw;
    } return self;
}
- (void)setOutgoing:(BOOL)outgoing { _outgoing=outgoing; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    if(w<36 || h<36) return;
    CGFloat l=3,t=3,r=w-11,b=h-6,c=18;
    // One continuous outline; the tail shares the fill and has no internal seam.
    UIBezierPath *path=[UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(l+c,t)];
    [path addLineToPoint:CGPointMake(r-c,t)];
    [path addQuadCurveToPoint:CGPointMake(r,t+c) controlPoint:CGPointMake(r,t)];
    [path addLineToPoint:CGPointMake(r,b-18)];
    [path addQuadCurveToPoint:CGPointMake(r+8,b) controlPoint:CGPointMake(r,b-7)];
    [path addQuadCurveToPoint:CGPointMake(r-10,b-3) controlPoint:CGPointMake(r-1,b)];
    [path addQuadCurveToPoint:CGPointMake(r-15,b) controlPoint:CGPointMake(r-12,b)];
    [path addLineToPoint:CGPointMake(l+c,b)];
    [path addQuadCurveToPoint:CGPointMake(l,b-c) controlPoint:CGPointMake(l,b)];
    [path addLineToPoint:CGPointMake(l,t+c)];
    [path addQuadCurveToPoint:CGPointMake(l+c,t) controlPoint:CGPointMake(l,t)];
    [path closePath];
    if(!self.outgoing) [path applyTransform:CGAffineTransformMake(-1,0,0,1,w,0)];
    UIColor *top=[UIColor whiteColor],*bottom=[UIColor colorWithWhite:0.82 alpha:1];
    if(self.outgoing) {
        NSString *theme=RPBubbleThemeName();
        if([theme isEqual:@"Blue"]) { top=[UIColor colorWithRed:0.81 green:0.92 blue:1 alpha:1]; bottom=[UIColor colorWithRed:0.42 green:0.67 blue:0.91 alpha:1]; }
        else if([theme isEqual:@"Pink"]) { top=[UIColor colorWithRed:1 green:0.89 blue:0.94 alpha:1]; bottom=[UIColor colorWithRed:0.94 green:0.59 blue:0.75 alpha:1]; }
        else if([theme isEqual:@"Purple"]) { top=[UIColor colorWithRed:0.93 green:0.88 blue:1 alpha:1]; bottom=[UIColor colorWithRed:0.73 green:0.60 blue:0.91 alpha:1]; }
        else if([theme isEqual:@"Amber"]) { top=[UIColor colorWithRed:1 green:0.96 blue:0.79 alpha:1]; bottom=[UIColor colorWithRed:0.96 green:0.78 blue:0.40 alpha:1]; }
        else { top=[UIColor colorWithRed:0.88 green:1 blue:0.72 alpha:1]; bottom=[UIColor colorWithRed:0.53 green:0.79 blue:0.30 alpha:1]; }
    }
    if(!self.outgoing) {
        NSString *theme=RPBubbleThemeName();
        if([theme isEqual:@"Blue"]) bottom=[UIColor colorWithRed:0.87 green:0.94 blue:1 alpha:1];
        else if([theme isEqual:@"Pink"]) bottom=[UIColor colorWithRed:1 green:0.88 blue:0.93 alpha:1];
        else if([theme isEqual:@"Purple"]) bottom=[UIColor colorWithRed:0.94 green:0.89 blue:1 alpha:1];
        else if([theme isEqual:@"Amber"]) bottom=[UIColor colorWithRed:1 green:0.95 blue:0.83 alpha:1];
    }
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context,CGSizeMake(0,1),2,[UIColor colorWithWhite:0 alpha:0.22].CGColor);
    [bottom setFill]; [path fill]; CGContextRestoreGState(context);
    CGContextSaveGState(context); [path addClip];
    if([RPBubbleThemeName() isEqual:@"Rainbow"]) {
        CGFloat alpha=self.outgoing ? 1 : 0.55;
        NSArray *colors=@[(id)[UIColor colorWithRed:1 green:0.68 blue:0.73 alpha:alpha].CGColor,(id)[UIColor colorWithRed:1 green:0.80 blue:0.59 alpha:alpha].CGColor,(id)[UIColor colorWithRed:1 green:0.96 blue:0.64 alpha:alpha].CGColor,(id)[UIColor colorWithRed:0.71 green:0.92 blue:0.69 alpha:alpha].CGColor,(id)[UIColor colorWithRed:0.65 green:0.84 blue:1 alpha:alpha].CGColor,(id)[UIColor colorWithRed:0.83 green:0.73 blue:0.96 alpha:alpha].CGColor];
        CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
        CGGradientRef rainbow=CGGradientCreateWithColors(space,(__bridge CFArrayRef)colors,NULL);
        CGContextDrawLinearGradient(context,rainbow,CGPointMake(0,t),CGPointMake(w,b),0);
        CGGradientRelease(rainbow); CGColorSpaceRelease(space);
    } else RPGradient(context,CGRectMake(0,t,w,b-t),top,bottom);
    RPGradient(context,CGRectMake(0,t,w,18),[UIColor colorWithWhite:1 alpha:0.25],[UIColor colorWithWhite:1 alpha:0]);
    CGContextRestoreGState(context);
    [[UIColor colorWithWhite:0.35 alpha:0.65] setStroke]; path.lineWidth=0.7; [path stroke];
}
@end
UIImage *RPClassicSendButton(BOOL pressed) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(60,36),NO,0);
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGRect rect=CGRectMake(1,1,58,33);
    UIBezierPath *path=[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7];
    CGContextSaveGState(context); [path addClip];
    RPGradient(context,rect,pressed ? [UIColor colorWithRed:0.19 green:0.38 blue:0.62 alpha:1] : [UIColor colorWithRed:0.53 green:0.71 blue:0.91 alpha:1], [UIColor colorWithRed:0.13 green:0.33 blue:0.59 alpha:1]);
    if(!pressed) { [[UIColor colorWithWhite:1 alpha:0.22] setFill]; UIRectFill(CGRectMake(0,0,60,17)); }
    CGContextRestoreGState(context);
    [[UIColor colorWithRed:0.14 green:0.25 blue:0.41 alpha:1] setStroke]; [path setLineWidth:1]; [path stroke];
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    return [image stretchableImageWithLeftCapWidth:10 topCapHeight:10];
}

UIImage *RPCharacterAvatar(NSDictionary *character) {
    id data=character[@"avatarData"];
    UIImage *custom=[data isKindOfClass:[NSData class]] ? [UIImage imageWithData:data] : nil;
    UIImage *image=custom ?: [UIImage imageNamed:[NSString stringWithFormat:@"Avatar-%@.png",RPBubbleThemeName()]];
    return image ? [UIImage imageWithCGImage:image.CGImage scale:2 orientation:image.imageOrientation] : nil;
}
