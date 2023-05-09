#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "Types.h"

NS_ASSUME_NONNULL_BEGIN

@interface SparseMatrix : NSObject

@property (readonly) index_t n;

@property (nonatomic, strong) id<MTLBuffer> colOffsets;
@property (nonatomic, strong) id<MTLBuffer> colLengths;
@property (nonatomic, strong) id<MTLBuffer> rowIndices;

@property (readonly) index_t* colOffsetsPtr;
@property (readonly) index_t* colLengthsPtr;
@property (readonly) index_t* rowIndicesPtr;

- (instancetype) initWithDevice: (id<MTLDevice>) device FromFile: (NSString *) path;

- (instancetype) initWithDevice: (id<MTLDevice>) device N: (index_t) n;

- (void) writeToFile: (NSString *) path;

- (index_t) getNumberOfNonZeros;

- (NSString *)description;


@end


NS_ASSUME_NONNULL_END
