#import <UIKit/UIKit.h>
UIColor *RPClassicBlue(void);
UIImage *RPClassicSendButton(BOOL pressed);
NSArray *RPBubbleThemeNames(void);
NSString *RPBubbleThemeName(void);
void RPSetBubbleTheme(NSString *name);
@interface RPClassicBubbleView : UIView
@property(nonatomic) BOOL outgoing;
@end

UIImage *RPCharacterAvatar(NSDictionary *character);
