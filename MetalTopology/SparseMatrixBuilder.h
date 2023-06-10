#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import "SparseMatrix.h"
#import "Types.h"

NS_ASSUME_NONNULL_BEGIN

@interface SparseMatrixBuilder : NSObject

- (instancetype)initWithInitialColumnsCapacity:(index_t)columns
                InitialNonZeroElementsCapacity:(index_t)nonZeros;

- (void)addColumn;

- (void)addNonZeroRowForLastColumn:(index_t)row;

- (index_t)getNonZeroElementsCount;

- (index_t)getColumnsCount;

- (SparseMatrix *)buildWithDevice:(id<MTLDevice>)device;

@end

NS_ASSUME_NONNULL_END
