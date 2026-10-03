#import <Foundation/Foundation.h>
#import "RPCharacterStore.h"
@interface MemoryDefaults : NSUserDefaults
@property(nonatomic,strong) NSMutableDictionary *values;
@end
@implementation MemoryDefaults
- (id)init { if ((self=[super init])) self.values=[NSMutableDictionary dictionary]; return self; }
- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (NSString *)stringForKey:(NSString *)key { return self.values[key]; }
- (NSArray *)arrayForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key {
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    self.values[key]=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
}
@end
static void Check(BOOL value, NSString *message) {
    if (!value) [NSException raise:@"RegressionFailure" format:@"%@",message];
}
int main(void) { @autoreleasepool {
    MemoryDefaults *defaults=[MemoryDefaults new];
    [defaults setObject:@"Original" forKey:@"character"];
    [defaults setObject:@"An explorer" forKey:@"persona"];
    [defaults setObject:@[@{@"role":@"user",@"content":@"Old chat"}] forKey:@"messages"];
    RPCharacterStore *store=[[RPCharacterStore alloc] initWithDefaults:defaults];
    NSMutableDictionary *first=store.characters[0];
    Check([first[@"name"] isEqual:@"Original"] && [first[@"messages"] count]==1, @"Migration preserves old character and chat");
    NSMutableDictionary *second=[store addCharacterNamed:@"Second" persona:@"A pilot"];
    [second[@"messages"] addObject:@{@"role":@"user",@"content":@"New chat"}];
    Check([first[@"messages"] count]==1 && ![first[@"messages"] isEqual:second[@"messages"]], @"Chats remain separate");
    [store setBusy:YES character:first];
    Check([store isBusy:first] && ![store isBusy:second], @"Pending requests lock only their character");
    [store setBusy:NO character:first];
    Check(![store isBusy:first], @"Completed requests unlock character");
    first[@"avatarData"]=[@"test-photo-data" dataUsingEncoding:NSUTF8StringEncoding];
    first[@"name"]=@"Renamed";
    [store save];
    store=[[RPCharacterStore alloc] initWithDefaults:defaults];
    Check([store.characters[0][@"avatarData"] isEqual:[@"test-photo-data" dataUsingEncoding:NSUTF8StringEncoding]],@"Custom avatar survives character reload");
    Check(store.characters.count==2 && [store.characters[0][@"name"] isEqual:@"Renamed"], @"Character edits survive reload");
    Check([store.characters[1][@"messages"][0][@"content"] isEqual:@"New chat"], @"Second chat survives reload");
    NSDictionary *single=store.characters[0];
    NSMutableDictionary *group=[store addGroupNamed:@"Campfire" memberIDs:[store.characters valueForKey:@"id"]];
    [group[@"messages"] addObject:@{@"role":@"user",@"content":@"Group only"}]; [store save];
    Check([single[@"messages"] count]==1,@"Group history cannot change a single chat");
    [store setBusy:YES character:group];
    Check([store isBusy:group] && ![store isBusy:single],@"Group and single requests lock independently");
    [store setBusy:NO character:group];
    store=[[RPCharacterStore alloc] initWithDefaults:defaults];
    Check(store.groups.count==1 && [store.groups[0][@"messages"] count]==1,@"Group and its history persist");
    Check([store participantsForGroup:store.groups[0]].count==2,@"Group resolves saved character identities");
    [store.characters[0][@"messages"] removeAllObjects];
    [store save];
    Check([store.characters[1][@"messages"] count]==1, @"New chat clears only selected character");
    [store removeCharacter:store.characters[0]];
    Check([store participantsForGroup:store.groups[0]].count==1,@"Deleted character is not requested in a group");
    Check([store.groups[0][@"messages"] count]==1,@"Deleting a character preserves group history");
    Check(store.characters.count==1 && [store.characters[0][@"name"] isEqual:@"Second"], @"Deleting one preserves the other");
    [store removeCharacter:store.characters[0]];
    store=[[RPCharacterStore alloc] initWithDefaults:defaults];
    Check(store.characters.count==0, @"Empty library does not repeat legacy migration");
    [store addCharacterNamed:@"Same" persona:@"Same"];
    [store addCharacterNamed:@"Same" persona:@"Same"];
    [store removeCharacter:store.characters[0]];
    Check(store.characters.count==1, @"Deleting identical characters removes only one");
    puts("PASS: migration, separate chats, saved edits/history, selected-chat clearing, deletion, empty-library restart, duplicate names.");
} return 0; }
