#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface Matrix : NSObject

@property (readonly) uint rows;
@property (readonly) uint cols;
@property (nonatomic, strong) id<MTLBuffer> dataBuffer;

- (instancetype) initWithDevice: (id<MTLDevice>) device Rows: (uint) rows Cols:(uint) cols;
- (NSInteger) getDataBufferOffsetForCol: (uint) col;

- (bool) getRow: (uint) row Col: (uint) col;
- (void) setRow: (uint) row Col: (uint) col Val: (bool) val;

- (void) fillFromArray: (bool*) array;

- (NSString *)description;


@end


NS_ASSUME_NONNULL_END
