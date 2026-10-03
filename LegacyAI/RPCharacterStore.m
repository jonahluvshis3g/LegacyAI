#import "RPCharacterStore.h"
static NSString *RPCreateIdentifier(void) {
    CFUUIDRef uuid=CFUUIDCreate(kCFAllocatorDefault);
    NSString *identifier=CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault,uuid));
    CFRelease(uuid); return identifier;
}
@interface RPCharacterStore ()
@property(nonatomic,strong,readwrite) NSMutableArray *characters;
@property(nonatomic,strong,readwrite) NSMutableArray *groups;
@property(nonatomic,strong) NSUserDefaults *defaults;
@property(nonatomic,strong) NSMutableSet *pendingIDs;
@end
@implementation RPCharacterStore
- (id)initWithDefaults:(NSUserDefaults *)defaults {
    if ((self = [super init])) {
        self.defaults = defaults;
        self.pendingIDs = [NSMutableSet set];
        self.characters = [NSMutableArray array];
        id saved = [defaults objectForKey:@"characterLibrary"];
        if ([saved isKindOfClass:[NSArray class]]) {
            for (id item in saved) {
                if (![item isKindOfClass:[NSDictionary class]] || ![item[@"name"] isKindOfClass:[NSString class]] || ![item[@"persona"] isKindOfClass:[NSString class]]) continue;
                NSMutableDictionary *character = [item mutableCopy];
                if (![character[@"id"] isKindOfClass:[NSString class]]) character[@"id"] = RPCreateIdentifier();
                NSMutableArray *history = [NSMutableArray array];
                if ([item[@"messages"] isKindOfClass:[NSArray class]]) {
                    for (id message in item[@"messages"]) {
                        if ([message isKindOfClass:[NSDictionary class]] && [message[@"content"] isKindOfClass:[NSString class]] &&
                            ([message[@"role"] isEqual:@"user"] || [message[@"role"] isEqual:@"assistant"])) [history addObject:message];
                    }
                }
                character[@"messages"] = history;
                [self.characters addObject:character];
            }
        } else {
            // One-time migration keeps the original character and conversation.
            NSMutableDictionary *character = [self addCharacterNamed:[defaults stringForKey:@"character"] ?: @"Mira"
                                                              persona:[defaults stringForKey:@"persona"] ?: @"A friendly fantasy explorer. Stay in character."];
            NSArray *legacy = [defaults arrayForKey:@"messages"];
            if (legacy) character[@"messages"] = [legacy mutableCopy];
        }
        self.groups=[NSMutableArray array];
        id savedGroups=[defaults objectForKey:@"groupLibrary"];
        if([savedGroups isKindOfClass:[NSArray class]]) for(id item in savedGroups) {
            if(![item isKindOfClass:[NSDictionary class]] || ![item[@"name"] isKindOfClass:[NSString class]] || ![item[@"memberIDs"] isKindOfClass:[NSArray class]]) continue;
            NSMutableDictionary *group=[item mutableCopy];
            if(![group[@"id"] isKindOfClass:[NSString class]]) group[@"id"]=RPCreateIdentifier();
            group[@"persona"]=@"Group roleplay";
            NSMutableArray *history=[NSMutableArray array];
            if([item[@"messages"] isKindOfClass:[NSArray class]]) for(id message in item[@"messages"]) {
                if([message isKindOfClass:[NSDictionary class]] && [message[@"content"] isKindOfClass:[NSString class]] && ([message[@"role"] isEqual:@"user"] || [message[@"role"] isEqual:@"assistant"])) [history addObject:message];
            }
            group[@"messages"]=history; [self.groups addObject:group];
        }
        [self save];
    }
    return self;
}
- (NSMutableDictionary *)addCharacterNamed:(NSString *)name persona:(NSString *)persona {
    NSMutableDictionary *character = [@{@"id":RPCreateIdentifier(), @"name":name, @"persona":persona, @"messages":[NSMutableArray array]} mutableCopy];
    [self.characters addObject:character];
    return character;
}
- (void)removeCharacter:(NSMutableDictionary *)character {
    [self.characters removeObjectIdenticalTo:character];
    [self save];
}
- (NSMutableDictionary *)addGroupNamed:(NSString *)name memberIDs:(NSArray *)memberIDs {
    NSMutableDictionary *group=[@{@"id":RPCreateIdentifier(),@"name":name,@"persona":@"Group roleplay",@"memberIDs":[memberIDs copy],@"messages":[NSMutableArray array]} mutableCopy];
    [self.groups addObject:group]; [self save]; return group;
}
- (NSArray *)participantsForGroup:(NSDictionary *)group {
    NSMutableArray *members=[NSMutableArray array];
    for(id identifier in group[@"memberIDs"]) for(NSDictionary *character in self.characters) {
        if([character[@"id"] isEqual:identifier]) { [members addObject:character]; break; }
    }
    return members;
}
- (void)removeGroup:(NSMutableDictionary *)group { [self.groups removeObjectIdenticalTo:group]; [self save]; }
- (BOOL)isBusy:(NSDictionary *)character {
    return [self.pendingIDs containsObject:character[@"id"]];
}
- (void)setBusy:(BOOL)busy character:(NSDictionary *)character {
    if (busy) [self.pendingIDs addObject:character[@"id"]];
    else [self.pendingIDs removeObject:character[@"id"]];
}
- (void)save {
    [self.defaults setObject:self.characters forKey:@"characterLibrary"];
    if(self.groups) [self.defaults setObject:self.groups forKey:@"groupLibrary"];
}
@end
