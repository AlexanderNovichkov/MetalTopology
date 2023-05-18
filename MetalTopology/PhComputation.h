#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "SparseMatrix.h"
#include "PersistencePairs.h"

NS_ASSUME_NONNULL_BEGIN

@interface PhComputation : NSObject
// metrics
@property(readonly) double computationTimeTotal;
@property(readonly) double computeLeftColsAndLeftRightPairsGpuTime;
@property(readonly) double computeMatrixColLengthsGpuTime;
@property(readonly) double computeMatrixColOffsetsTime;
@property(readonly) double executeLeftRightAdditionsGpuTime;
@property(readonly) double computeLowAndLeftColByLowGPUTime;
@property(readonly) double computeNonZeroColsGPUTime;
@property(readonly) double executeCopyLeftColumnsOnGpuTime;


- (instancetype) initWithDevice: (id<MTLDevice>) device Matrix: (SparseMatrix*) matrix;
- (SparseMatrix*) makeReduction;
- (PersistencePairs*) getPersistentPairs;
@end

NS_ASSUME_NONNULL_END
