#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface PersistencePair : NSObject

@property uint32_t birth;
@property uint32_t death;

@end


@interface PersistencePairs : NSObject

@property (readonly) NSMutableArray* pairs;

- (instancetype) init;

- (instancetype) initFromFile: (NSString *) path;

- (void) sortPairsByBirth;

- (void) writeToFile: (NSString *) path;

- (NSString *)description;

@end

NS_ASSUME_NONNULL_END
