#import <Foundation/Foundation.h>
#import <objc/runtime.h>
// iOS 5 lacks the subscripting selectors emitted by modern Objective-C compilers.
// Install adapters only when the runtime does not already implement them.
static id RPDictionaryGet(id self, SEL cmd, id key) { return [self objectForKey:key]; }
static void RPDictionarySet(id self, SEL cmd, id value, id key) {
    if(value) [self setObject:value forKey:key]; else [self removeObjectForKey:key];
}
static id RPArrayGet(id self, SEL cmd, NSUInteger index) { return [self objectAtIndex:index]; }
static void RPArraySet(id self, SEL cmd, id value, NSUInteger index) {
    if(index==[self count]) [self addObject:value]; else [self replaceObjectAtIndex:index withObject:value];
}
@interface RPLegacyCompatibility : NSObject
@end
@implementation RPLegacyCompatibility
+ (void)load {
    class_addMethod([NSDictionary class],@selector(objectForKeyedSubscript:),(IMP)RPDictionaryGet,"@@:@");
    class_addMethod([NSMutableDictionary class],@selector(setObject:forKeyedSubscript:),(IMP)RPDictionarySet,"v@:@@");
    class_addMethod([NSArray class],@selector(objectAtIndexedSubscript:),(IMP)RPArrayGet,"@@:I");
    class_addMethod([NSMutableArray class],@selector(setObject:atIndexedSubscript:),(IMP)RPArraySet,"v@:@I");
}
@end
