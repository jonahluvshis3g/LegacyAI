"""Compile actual controller methods against a tiny macOS table/navigation stub."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'main.m').read_text()

def method(start, end):
    pos = source.index(start, source.index('@implementation ChatController'))
    return source[pos:source.index(end, pos)]

scroll = method('- (void)scrollToLast {', '- (void)render {')
appear = method('- (void)viewDidAppear:', '- (void)dealloc')
prefix = r'''
#import <Foundation/Foundation.h>
#define UITableViewScrollPositionBottom 2
@interface NSIndexPath (Rows)
+ (id)indexPathForRow:(NSInteger)row inSection:(NSInteger)section;
@property(nonatomic,readonly) NSInteger row;
@end
@implementation NSIndexPath (Rows)
+ (id)indexPathForRow:(NSInteger)row inSection:(NSInteger)section { NSUInteger indexes[]={section,row}; return [self indexPathWithIndexes:indexes length:2]; }
- (NSInteger)row { return [self indexAtPosition:1]; }
@end
@interface Table : NSObject
@property(nonatomic,strong) id window;
@property(nonatomic) NSInteger rows;
@property(nonatomic) NSInteger pendingRows;
@property(nonatomic) NSInteger scrolls;
@property(nonatomic) NSInteger lastRow;
- (void)layoutIfNeeded;
- (NSInteger)numberOfSections;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;
- (void)scrollToRowAtIndexPath:(NSIndexPath *)path atScrollPosition:(NSInteger)position animated:(BOOL)animated;
@end
@implementation Table
- (void)layoutIfNeeded { self.rows=self.pendingRows; }
- (NSInteger)numberOfSections { return 1; }
- (NSInteger)numberOfRowsInSection:(NSInteger)section { return self.rows; }
- (void)scrollToRowAtIndexPath:(NSIndexPath *)path atScrollPosition:(NSInteger)position animated:(BOOL)animated {
    if(path.row<0 || path.row>=self.rows) [NSException raise:@"InvalidScroll" format:@"Row beyond current table"];
    self.scrolls++; self.lastRow=path.row;
}
@end
@interface Navigation : NSObject
@property(nonatomic,strong) id topViewController;
@end
@implementation Navigation
@end
@interface Base : NSObject
- (void)viewDidAppear:(BOOL)animated;
@end
@implementation Base
- (void)viewDidAppear:(BOOL)animated {}
@end
@interface ChatController : Base
@property(nonatomic,strong) Table *chatTable;
@property(nonatomic,strong) Navigation *navigationController;
@property(nonatomic) BOOL replyAfterEdit;
@property(nonatomic) NSInteger renders;
@property(nonatomic) NSInteger refreshes;
- (void)scrollToLast;
- (void)render;
- (void)refreshLast;
@end
@implementation ChatController
- (void)render { self.renders++; }
- (void)refreshLast { self.refreshes++; }
'''
suffix = r'''
@end
static void Check(BOOL value, NSString *message) {
    if(!value) [NSException raise:@"Failure" format:@"%@",message];
}
int main(void) { @autoreleasepool {
    ChatController *c=[ChatController new]; c.chatTable=[Table new]; c.chatTable.window=[NSObject new];
    c.navigationController=[Navigation new]; c.navigationController.topViewController=c;
    c.chatTable.rows=4; c.chatTable.pendingRows=1; [c scrollToLast];
    Check(c.chatTable.lastRow==0,@"Scroll uses actual post-layout row count after first-message edit");
    c.chatTable.pendingRows=4; [c scrollToLast];
    Check(c.chatTable.lastRow==3,@"Scroll after later send uses updated rows");
    NSInteger scrolls=c.chatTable.scrolls; c.chatTable.pendingRows=0; [c scrollToLast];
    Check(c.chatTable.scrolls==scrolls,@"Empty table does not scroll out of range");
    c.chatTable.pendingRows=1; c.chatTable.window=nil; [c scrollToLast];
    Check(c.chatTable.scrolls==scrolls,@"Detached table does not scroll");
    c.chatTable.window=[NSObject new]; c.navigationController.topViewController=[NSObject new]; [c scrollToLast];
    Check(c.chatTable.scrolls==scrolls,@"Hidden chat does not scroll during editor pop");
    c.replyAfterEdit=YES; [c viewDidAppear:NO]; [c viewDidAppear:NO];
    Check(c.refreshes==1 && !c.replyAfterEdit,@"Edited user message triggers exactly one automatic reply on return");
    c.navigationController.topViewController=nil;
    puts("PASS: actual controller methods guard stale/empty/hidden rows and auto-reply once after editing.");
} return 0; }
'''
with tempfile.TemporaryDirectory(prefix='roleplay6-ui-check-') as temp:
    path = Path(temp)
    (path/'check.m').write_text(prefix + scroll + appear + suffix)
    subprocess.run(['clang', '-fobjc-arc', '-framework', 'Foundation', str(path/'check.m'), '-o', str(path/'check')], check=True)
    subprocess.run([str(path/'check')], check=True)
