#import "SparseMatrixBuilder.h"

@implementation SparseMatrixBuilder
{
    NSMutableData* _colOffsets;
    NSMutableData* _colLengths;
    NSMutableData* _rowIndices;
}


- (instancetype) initWithInitialColumnsCapacity: (index_t) columns InitialNonZeroElementsCapacity: (index_t) nonZeros {
    self = [super init];
    if(self){
        _colOffsets = [NSMutableData dataWithCapacity:columns * sizeof(index_t)];
        _colLengths = [NSMutableData dataWithCapacity:columns * sizeof(index_t)];
        _rowIndices = [NSMutableData dataWithCapacity:nonZeros * sizeof(index_t)];
    }
    return self;
}

- (void) addColumn {
    index_t offset = [self getNonZeroElementsCount];
    [_colOffsets appendBytes: &offset length: sizeof(index_t)];
    
    [_colLengths increaseLengthBy: sizeof(index_t)];
}

- (void) addNonZeroRowForLastColumn: (index_t) row {
    [_rowIndices appendBytes:&row length:sizeof(index_t)];
    
    index_t* colLengthsPtr = [_colLengths mutableBytes];
    colLengthsPtr[[self getColumnsCount] - 1]++;
}

- (index_t) getNonZeroElementsCount {
    return _rowIndices.length / sizeof(index_t);
}

- (index_t) getColumnsCount {
    return _colOffsets.length / sizeof(index_t);
}

- (SparseMatrix*) buildWithDevice: (id<MTLDevice>) device {
    return [[SparseMatrix alloc] initWithDevice:device ColOffsets:_colOffsets ColLengths:_colLengths RowIndices:_rowIndices];
}


@end

