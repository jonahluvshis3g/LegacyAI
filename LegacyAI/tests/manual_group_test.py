"""Exercise actual Send and character-icon methods with Foundation stubs."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'main.m').read_text()
def extract(a,b):
    start=s.index(a,s.index('@implementation ChatController'))
    return s[start:s.index(b,start)]
code=r'''
#import <Foundation/Foundation.h>
@interface UIButton:NSObject
@property NSInteger tag;
@end
@implementation UIButton
@end
@interface Field:NSObject
@property(copy) NSString *text;
- (void)resignFirstResponder;
@end
@implementation Field
- (void)resignFirstResponder {}
@end
@interface Store:NSObject
@property BOOL busy;
- (BOOL)isBusy:(id)c;
- (NSArray *)participantsForGroup:(id)c;
@end
@implementation Store
- (BOOL)isBusy:(id)c {return self.busy;}
- (NSArray *)participantsForGroup:(id)c {return @[@{@"id":@"a"},@{@"id":@"b"}];}
@end
@interface ChatController:NSObject
@property(strong) Store *store;
@property(strong) NSDictionary *character;
@property(strong) NSArray *messages;
@property(strong) Field *input;
@property(strong) NSMutableSet *selectedSpeakers;
@property NSInteger requests;
- (void)send;
- (void)toggleMember:(UIButton *)button;
- (void)alert:(NSString *)message;
- (void)commitHistory:(NSArray *)context;
- (void)requestContext:(NSArray *)context pendingInput:(NSString *)input;
@end
@implementation ChatController
- (void)alert:(NSString *)message {}
- (void)commitHistory:(NSArray *)context {self.messages=context;}
- (void)requestContext:(NSArray *)context pendingInput:(NSString *)input {self.requests++;}
'''
code+=extract('- (void)send {','- (void)requestContext:')+extract('- (void)toggleMember:','- (void)scrollToLast {')
code+=r'''
@end
static void Check(BOOL ok) {if(!ok) abort();}
int main(){@autoreleasepool{
 ChatController *c=[ChatController new];c.store=[Store new];c.input=[Field new];c.messages=@[];
 c.character=@{@"memberIDs":@[@"a",@"b"]};c.input.text=@"Hello";[c send];
 Check(c.requests==0 && c.messages.count==1 && !c.input.text.length);
 UIButton *b=[UIButton new];b.tag=1;[c toggleMember:b];
 Check(c.requests==1 && c.selectedSpeakers.count==1 && [c.selectedSpeakers containsObject:@"b"]);
 b.tag=0;[c toggleMember:b];Check(c.requests==2 && c.selectedSpeakers.count==1 && [c.selectedSpeakers containsObject:@"a"]);
 c.store.busy=YES;[c toggleMember:b];Check(c.requests==2);c.store.busy=NO;
 c.character=@{};c.input.text=@"Single chat";[c send];Check(c.requests==3);
 puts("PASS: group Send saves without AI; icons request one speaker; single Send requests AI.");
}return 0;}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'check.m').write_text(code)
 subprocess.run(['clang','-fobjc-arc','-framework','Foundation',str(p/'check.m'),'-o',str(p/'check')],check=True)
 subprocess.run([str(p/'check')],check=True)
