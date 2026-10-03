#import <Foundation/Foundation.h>

@interface RPCharacterStore : NSObject
@property(nonatomic,strong,readonly) NSMutableArray *characters;
@property(nonatomic,strong,readonly) NSMutableArray *groups;
- (id)initWithDefaults:(NSUserDefaults *)defaults;
- (NSMutableDictionary *)addCharacterNamed:(NSString *)name persona:(NSString *)persona;
- (void)removeCharacter:(NSMutableDictionary *)character;
- (NSMutableDictionary *)addGroupNamed:(NSString *)name memberIDs:(NSArray *)memberIDs;
- (NSArray *)participantsForGroup:(NSDictionary *)group;
- (void)removeGroup:(NSMutableDictionary *)group;
- (void)save;
- (BOOL)isBusy:(NSDictionary *)character;
- (void)setBusy:(BOOL)busy character:(NSDictionary *)character;
@end
