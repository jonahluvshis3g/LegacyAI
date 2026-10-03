#import <Foundation/Foundation.h>
#import "RPChatHistory.h"
static void Check(BOOL value, NSString *message) {
    if(!value) [NSException raise:@"RegressionFailure" format:@"%@",message];
}
int main(void) { @autoreleasepool {
    NSArray *history=@[@{@"role":@"user",@"content":@"Hello"},@{@"role":@"assistant",@"content":@"Welcome"},@{@"role":@"user",@"content":@"Next"},@{@"role":@"assistant",@"content":@"Continue"}];
    NSArray *edit=RPHistoryWithEdit(history,0,@" Revised ");
    Check(edit.count==1 && [edit[0][@"content"] isEqual:@"Revised"],@"Edit updates text and discards later messages");
    edit=RPHistoryWithEdit(history,1,@"Different welcome");
    Check(edit.count==2 && [edit[1][@"role"] isEqual:@"assistant"],@"Editing assistant preserves role");
    Check(!RPHistoryWithEdit(history,99,@"No") && !RPHistoryWithEdit(history,0,@"  "),@"Invalid edits cannot mutate history");
    NSArray *deleted=RPHistoryWithDeletion(history,1);
    Check(deleted.count==3 && [deleted[1][@"content"] isEqual:@"Next"],@"Delete removes selected message only");
    Check(!RPHistoryWithDeletion(history,99),@"Out-of-range delete rejected");
    NSArray *context=RPRegenerationContext(history,1);
    Check(context.count==1 && [context.lastObject[@"role"] isEqual:@"user"],@"Earlier refresh uses earlier context");
    NSArray *reply=RPHistoryWithReply(context,@"New welcome");
    Check(reply.count==2 && [reply.lastObject[@"content"] isEqual:@"New welcome"],@"Refresh replaces reply and later turns");
    context=RPRegenerationContext(history,3);
    reply=RPHistoryWithReply(context,@"New ending");
    Check(reply.count==4 && [reply[1][@"content"] isEqual:@"Welcome"],@"Last refresh preserves earlier turns");
    Check(!RPRegenerationContext(history,0) && !RPRegenerationContext(@[@{@"role":@"assistant",@"content":@"Orphan"}],0),@"Refresh requires an earlier user turn");
    Check(!RPHistoryWithReply(@[],@"No") && !RPHistoryWithReply(history,@"No") && !RPHistoryWithReply(context,@""),@"Invalid replacement rejected");
    Check(history.count==4 && [history[1][@"content"] isEqual:@"Welcome"],@"Original stays intact while preparing replacement or on failure");
    NSArray *editedFirst=RPHistoryWithEdit(history,0,@"Edited opening");
    NSArray *automaticReply=RPHistoryWithReply(editedFirst,@"Answer to edited opening");
    NSMutableArray *next=[automaticReply mutableCopy];
    [next addObject:@{@"role":@"user",@"content":@"Another message"}];
    NSArray *nextReply=RPHistoryWithReply(next,@"Another answer");
    Check(nextReply.count==4 && [nextReply[0][@"content"] isEqual:@"Edited opening"] && [nextReply[2][@"content"] isEqual:@"Another message"],@"Editing first message, automatic reply, then another message preserves a valid history");
    NSArray *groupReplies=@[@{@"speakerID":@"a",@"speaker":@"Mira",@"content":@"Hello"},@{@"speakerID":@"b",@"speaker":@"Pencil",@"content":@"Hi"}];
    NSArray *groupHistory=RPHistoryWithGroupReplies(editedFirst,groupReplies,@[@"a",@"b"]);
    Check(groupHistory.count==3 && [groupHistory[2][@"speaker"] isEqual:@"Pencil"],@"Group round preserves distinct speaker identities");
    Check(RPHistoryWithGroupReplies(groupHistory,@[groupReplies[0]],@[@"a"]).count==4,@"Manual character turn can follow another character");
    Check(RPHistoryWithGroupReplies(@[],@[groupReplies[0]],@[@"a"]).count==1,@"Character can open an empty scene");
    NSArray *groupEdit=RPHistoryWithEdit(groupHistory,1,@"Changed reply");
    Check([groupEdit[1][@"speakerID"] isEqual:@"a"],@"Editing a group message keeps its speaker");
    Check(!RPHistoryWithGroupReplies(editedFirst,groupReplies,@[@"a"]),@"Unexpected group speakers are rejected");
    Check(!RPHistoryWithGroupReplies(editedFirst,@[groupReplies[0],groupReplies[0]],@[@"a",@"b"]),@"Duplicate group responses are rejected");
    NSArray *refreshed=RPHistoryWithRefreshedReply(history,1,@{@"role":@"assistant",@"content":@"New welcome"});
    Check(refreshed.count==history.count && [refreshed[0] isEqual:history[0]] && [refreshed[2] isEqual:history[2]] && [refreshed[3] isEqual:history[3]],@"Refresh preserves every other turn");
    Check([refreshed[1][@"content"] isEqual:@"New welcome"] && [history[1][@"content"] isEqual:@"Welcome"],@"Only refreshed text changes, original remains intact");
    refreshed=RPHistoryWithRefreshedReply(groupHistory,1,@{@"content":@"New Mira line",@"speakerID":@"a"});
    Check(refreshed.count==3 && [refreshed[2] isEqual:groupHistory[2]] && [refreshed[1][@"speaker"] isEqual:@"Mira"],@"Group refresh keeps other speakers and metadata");
    Check(!RPHistoryWithRefreshedReply(groupHistory,1,@{@"content":@"Wrong speaker",@"speakerID":@"b"}) && !RPHistoryWithRefreshedReply(history,0,@{@"content":@"No"}) && !RPHistoryWithRefreshedReply(history,99,@{@"content":@"No"}) && !RPHistoryWithRefreshedReply(history,1,@{@"content":@""}),@"Invalid refresh cannot replace a message");
    puts("PASS: user/assistant editing, truncation, selected deletion, earlier/last regeneration, invalid inputs, unchanged original history.");
} return 0; }
