"""Exercise the actual action-sheet cancel guards with a macOS Foundation stub."""
from pathlib import Path
import subprocess
import tempfile
source = (Path(__file__).resolve().parents[1] / 'main.m').read_text()
start = source.index('- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {')
end = source.index('    if([self.store isBusy:', start)
guard = source[start:end] + '    self.actions++;\n}\n'
code = r'''
#import <Foundation/Foundation.h>
@interface UIActionSheet : NSObject
@property(nonatomic) NSInteger cancelButtonIndex;
@property(nonatomic) NSInteger dismisses;
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated;
@end
@implementation UIActionSheet
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated { self.dismisses++; }
@end
@interface Chat : NSObject
@property(nonatomic) NSInteger actions;
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index;
@end
@implementation Chat
''' + guard + r'''
@end
int main(void) { @autoreleasepool {
    Chat *chat=[Chat new]; UIActionSheet *sheet=[UIActionSheet new]; sheet.cancelButtonIndex=4;
    [chat actionSheet:sheet clickedButtonAtIndex:4];
    NSCAssert(sheet.dismisses==1 && chat.actions==0,@"Cancel dismisses without modifying messages");
    [chat actionSheet:sheet clickedButtonAtIndex:-1];
    NSCAssert(sheet.dismisses==2 && chat.actions==0,@"System cancel safely dismisses");
    [chat actionSheet:sheet clickedButtonAtIndex:0];
    NSCAssert(chat.actions==1,@"Regular actions remain available");
    puts("PASS: Cancel dismisses the sheet without performing a message action.");
} return 0; }
'''
with tempfile.TemporaryDirectory(prefix='roleplay6-cancel-') as temp:
    path=Path(temp)
    (path/'check.m').write_text(code)
    subprocess.run(['clang','-fobjc-arc','-framework','Foundation',str(path/'check.m'),'-o',str(path/'check')],check=True)
    subprocess.run([str(path/'check')],check=True)
