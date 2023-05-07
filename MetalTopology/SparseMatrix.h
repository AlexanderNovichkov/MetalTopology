#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface SparseMatrix : NSObject

@property (readonly) uint32_t n;

@property (nonatomic, strong) id<MTLBuffer> colOffsets;
@property (nonatomic, strong) id<MTLBuffer> colLengths;
@property (nonatomic, strong) id<MTLBuffer> rowIndices;

@property (readonly) uint32_t* colOffsetsPtr;
@property (readonly) uint32_t* colLengthsPtr;
@property (readonly) uint32_t* rowIndicesPtr;

- (instancetype) initWithDevice: (id<MTLDevice>) device FromFile: (NSString *) path;

- (instancetype) initWithDevice: (id<MTLDevice>) device N: (uint32_t) n;

- (void) writeToFile: (NSString *) path;

- (uint32_t) getNumberOfNonZeros;

- (NSString *)description;


@end


NS_ASSUME_NONNULL_END
