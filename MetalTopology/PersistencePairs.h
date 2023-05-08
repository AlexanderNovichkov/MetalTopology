#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface PersistencePair : NSObject

@property uint32_t left;
@property uint32_t right;

@end


@interface PersistencePairs : NSObject

@property (readonly) NSMutableArray* pairs;

- (instancetype) init;

- (instancetype) initFromFile: (NSString *) path;

- (void) sortPairsByLeft;

- (void) writeToFile: (NSString *) path;

- (NSString *)description;

@end

NS_ASSUME_NONNULL_END
