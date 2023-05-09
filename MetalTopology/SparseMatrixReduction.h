#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "SparseMatrix.h"
#include "PersistencePairs.h"

NS_ASSUME_NONNULL_BEGIN

@interface SparseMatrixReduction : NSObject
// metrics
@property(readonly) double computationTimeTotal;
@property(readonly) double colAdditionsGPUTime;
@property(readonly) double computeLowAndLeftColByLowGPUTime;
@property(readonly) double computeNonZeroColsGPUTime;


- (instancetype) initWithDevice: (id<MTLDevice>) device Matrix: (SparseMatrix*) matrix;
- (SparseMatrix*) makeReduction;
- (PersistencePairs*) getPersistentPairs;
@end

NS_ASSUME_NONNULL_END
