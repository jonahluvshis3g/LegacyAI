#import "RPChatHistory.h"
NSArray *RPHistoryWithEdit(NSArray *history, NSUInteger index, NSString *text) {
    NSString *trimmed=[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(index>=history.count || !trimmed.length || trimmed.length>8000) return nil;
    NSMutableArray *result=[[history subarrayWithRange:NSMakeRange(0,index+1)] mutableCopy];
    NSMutableDictionary *message=[history[index] mutableCopy];
    message[@"content"]=trimmed; result[index]=message;
    return result;
}
NSArray *RPHistoryWithDeletion(NSArray *history, NSUInteger index) {
    if(index>=history.count) return nil;
    NSMutableArray *result=[history mutableCopy];
    [result removeObjectAtIndex:index];
    return result;
}
NSArray *RPRegenerationContext(NSArray *history, NSUInteger index) {
    if(index>=history.count || ![history[index][@"role"] isEqual:@"assistant"]) return nil;
    // An AI request must end in a user message. Find the user turn for this reply.
    for(NSInteger i=(NSInteger)index-1;i>=0;i--) {
        if([history[(NSUInteger)i][@"role"] isEqual:@"user"])
            return [history subarrayWithRange:NSMakeRange(0,(NSUInteger)i+1)];
    }
    return nil;
}
NSArray *RPHistoryWithReply(NSArray *context, NSString *reply) {
    if(!context.count || ![context.lastObject[@"role"] isEqual:@"user"] || !reply.length || reply.length>16000) return nil;
    NSMutableArray *result=[context mutableCopy];
    [result addObject:@{@"role":@"assistant",@"content":reply}];
    return result;
}

NSArray *RPHistoryWithGroupReplies(NSArray *context, NSArray *replies, NSArray *allowedIDs) {
    if(![context isKindOfClass:[NSArray class]] || ![replies isKindOfClass:[NSArray class]] || !replies.count || replies.count!=allowedIDs.count) return nil;
    NSMutableArray *result=[context mutableCopy]; NSMutableSet *seen=[NSMutableSet set];
    for(id reply in replies) {
        if(![reply isKindOfClass:[NSDictionary class]] || ![reply[@"speakerID"] isKindOfClass:[NSString class]] || ![allowedIDs containsObject:reply[@"speakerID"]] || [seen containsObject:reply[@"speakerID"]] || ![reply[@"speaker"] isKindOfClass:[NSString class]] || ![reply[@"content"] isKindOfClass:[NSString class]] || ![reply[@"content"] length] || [reply[@"content"] length]>16000) return nil;
        [seen addObject:reply[@"speakerID"]];
        [result addObject:@{@"role":@"assistant",@"content":reply[@"content"],@"speakerID":reply[@"speakerID"],@"speaker":reply[@"speaker"]}];
    }
    return result;
}

NSArray *RPHistoryWithRefreshedReply(NSArray *history, NSUInteger index, NSDictionary *reply) {
    if(index>=history.count || ![history[index][@"role"] isEqual:@"assistant"] || ![reply[@"content"] isKindOfClass:[NSString class]] || ![reply[@"content"] length] || [reply[@"content"] length]>16000) return nil;
    NSString *speaker=history[index][@"speakerID"];
    if(speaker && ![speaker isEqual:reply[@"speakerID"]]) return nil;
    NSMutableArray *result=[history mutableCopy];
    NSMutableDictionary *replacement=[history[index] mutableCopy];
    replacement[@"content"]=reply[@"content"];
    result[index]=replacement;
    return result;
}
