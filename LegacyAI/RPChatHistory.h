#import <Foundation/Foundation.h>
// Return a new history, leaving the original intact until the operation succeeds.
NSArray *RPHistoryWithEdit(NSArray *history, NSUInteger index, NSString *text);
NSArray *RPHistoryWithDeletion(NSArray *history, NSUInteger index);
NSArray *RPRegenerationContext(NSArray *history, NSUInteger index);
NSArray *RPHistoryWithReply(NSArray *context, NSString *reply);

NSArray *RPHistoryWithGroupReplies(NSArray *context, NSArray *replies, NSArray *allowedIDs);

NSArray *RPHistoryWithRefreshedReply(NSArray *history, NSUInteger index, NSDictionary *reply);
