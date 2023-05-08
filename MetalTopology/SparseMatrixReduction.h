#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "SparseMatrix.h"
#include "PersistencePairs.h"

NS_ASSUME_NONNULL_BEGIN

@interface SparseMatrixReduction : NSObject
- (instancetype) initWithDevice: (id<MTLDevice>) device Matrix: (SparseMatrix*) matrix;
- (SparseMatrix*) makeReduction;
- (PersistencePairs*) getPersistentPairs;
@end

NS_ASSUME_NONNULL_END
