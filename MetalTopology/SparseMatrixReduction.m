#import "SparseMatrixReduction.h"

#include <stdint.h>
#include "Types.h"

void addMatrixColumns2(const index_t *matrixColOffsets,
                               const index_t *matrixColLengths,
                               const index_t *matrixRowIndices,
                               const index_t *resultMatrixColOffsets,
                               index_t *resultMatrixColLengths,
                               index_t *resultMatrixRowIndices,
                               const index_t * colToAdd,
                               index_t rightCol)
{
    const index_t leftCol = colToAdd[rightCol];
    
    index_t leftColOffsetCur = (leftCol == MAX_INDEX) ? MAX_INDEX : matrixColOffsets[leftCol];
    const index_t leftColOffsetEnd = (leftCol == MAX_INDEX) ? MAX_INDEX : (leftColOffsetCur + matrixColLengths[leftCol]);
    
    index_t rightColOffsetCur = matrixColOffsets[rightCol];
    const index_t rightColOffsetEnd = rightColOffsetCur + matrixColLengths[rightCol];
    
    index_t resultColOffsetCur = resultMatrixColOffsets[rightCol];
    
    while (leftColOffsetCur < leftColOffsetEnd || rightColOffsetCur < rightColOffsetEnd) {
        index_t leftRow = (leftColOffsetCur < leftColOffsetEnd) ? matrixRowIndices[leftColOffsetCur] : MAX_INDEX;
        index_t rightRow = (rightColOffsetCur < rightColOffsetEnd) ? matrixRowIndices[rightColOffsetCur] : MAX_INDEX;
        
        if(leftRow < rightRow) {
            resultMatrixRowIndices[resultColOffsetCur] = leftRow;
            leftColOffsetCur++;
            resultColOffsetCur++;
        } else if(leftRow > rightRow) {
            resultMatrixRowIndices[resultColOffsetCur] = rightRow;
            rightColOffsetCur++;
            resultColOffsetCur++;
        } else {
            leftColOffsetCur++;
            rightColOffsetCur++;
        }
    }
    
    resultMatrixColLengths[rightCol] = resultColOffsetCur - resultMatrixColOffsets[rightCol];
}


@implementation SparseMatrixReduction
{
    // metal variables
    id<MTLDevice> _mDevice;
    id<MTLCommandQueue> _mCommandQueue;
    id<MTLComputePipelineState> _mAddMatrixColumnsPSO;
    id<MTLComputePipelineState> _mComputeLowPSO;
    
    // metrics
    double _colAdditionsGPUTime;
    
    // State variables, updated every iteration of algorithm
    SparseMatrix * _matrix;
    
    id<MTLBuffer> _low;
    index_t* _lowPtr;
    id<MTLBuffer> _leftColByLow;
    index_t* _leftColByLowPtr;
    
    
    index_t _nonZeroColsCount;
    id<MTLBuffer> _nonZeroCols;
    index_t* _nonZeroColsPtr;
    

    id<MTLBuffer> _colToAdd;
    index_t* _colToAddPtr;
    
    // Optimization variables, allow us not to allocate memory every iteration
    SparseMatrix * _matrixToSumCols;


}

- (instancetype) initWithDevice: (id<MTLDevice>) device Matrix: (SparseMatrix*) matrix
{
    self = [super init];
    if (self)
    {

        _mDevice = device;
        
        NSError* error = nil;

        id<MTLLibrary> defaultLibrary = [_mDevice newDefaultLibraryWithBundle:[NSBundle bundleForClass: [self class]] error:nil];
        if (defaultLibrary == nil)
        {
            NSLog(@"Failed to find the default library.");
            return nil;
        }
        
        id<MTLFunction> addMatrixColumns = [defaultLibrary newFunctionWithName:@"addMatrixColumns"];
        if (addMatrixColumns == nil)
        {
            NSLog(@"Failed to find metal function addMatrixColumns");
            return nil;
        }
        _mAddMatrixColumnsPSO = [_mDevice newComputePipelineStateWithFunction: addMatrixColumns error:&error];
        if (_mAddMatrixColumnsPSO == nil)
        {
            NSLog(@"Failed to created pipeline state object, error %@.", error);
            return nil;
        }
        
        id<MTLFunction> computeLow = [defaultLibrary newFunctionWithName:@"computeLow"];
        if (computeLow == nil)
        {
            NSLog(@"Failed to find metal function computeLow");
            return nil;
        }
        _mComputeLowPSO = [_mDevice newComputePipelineStateWithFunction: computeLow error:&error];
        if (_mComputeLowPSO == nil)
        {
            NSLog(@"Failed to created pipeline state object, error %@.", error);
            return nil;
        }
        
        
        _mCommandQueue = [_mDevice newCommandQueue];
        if (_mCommandQueue == nil)
        {
            NSLog(@"Failed to find the command queue.");
            return nil;
        }
        
        _matrix = matrix;
        _matrixToSumCols = [[SparseMatrix alloc] initWithDevice: _mDevice N:_matrix.n];
        
        _nonZeroColsCount = 0;
        _nonZeroCols = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t) options:MTLResourceStorageModeShared];
        _nonZeroColsPtr = _nonZeroCols.contents;
        for(index_t col = 0; col < _matrix.n; col++) {
            if(_matrix.colLengthsPtr[col] != 0) {
                _nonZeroColsPtr[_nonZeroColsCount++] = col;
            }
        }
        
        _low = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t) options:MTLResourceStorageModeShared];
        _lowPtr = _low.contents;
        _leftColByLow = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t) options:MTLResourceStorageModeShared];
        _leftColByLowPtr = _leftColByLow.contents;
        for(index_t col = 0; col < _matrix.n; col++) {
            _leftColByLowPtr[col] = MAX_INDEX;
        }
        for(index_t col = 0; col < _matrix.n; col++) {
            index_t length = _matrix.colLengthsPtr[col];
            if(length == 0) {
                _lowPtr[col] = MAX_INDEX;
            } else {
                index_t offset = _matrix.colOffsetsPtr[col];
                index_t low = _matrix.rowIndicesPtr[offset + length - 1];
                _lowPtr[col] = low;
                if(_leftColByLowPtr[low] > col) {
                    _leftColByLowPtr[low] = col;
                }
            }
        }
        
        _colToAdd = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t) options:MTLResourceStorageModeShared];
        _colToAddPtr = _colToAdd.contents;
    }
    
    return self;
}

- (PersistencePairs*) getPersistentPairs {
    PersistencePairs *pairs = [[PersistencePairs alloc] init];
    for(index_t i = 0; i < _nonZeroColsCount;i++) {
        index_t col = _nonZeroColsPtr[i];
        PersistencePair * pair = [[PersistencePair alloc] init];
        pair.birth = _lowPtr[col];
        pair.death = col;
        [pairs.pairs addObject:pair];
    }
    [pairs sortPairsByBirth];
    return pairs;
}

- (SparseMatrix*) makeReduction
{
    
    index_t it = 0;
    while (true){
        @autoreleasepool {
            it++;
            NSLog(@"Iteration start: %u", it);
            
//            [self MakeClearing];
            
            if( [self isMatrixReduced]) {
                break;
            }
            
            [self computeColToAdd];
            
            [self addColumns];
            
            [self computeLowAndLeftColByLow];
            
            [self computeNonZeroCols];
        }
    }
    
    NSLog(@"STATS");
    NSLog(@"_colAdditionsGPUTime=%f", _colAdditionsGPUTime);
    
    return _matrix;
}

- (void) computeNonZeroCols {
    NSLog(@"Start method computeNonZeroCols");
    index_t writePos = 0;
    for(index_t i = 0; i < _nonZeroColsCount;i++) {
        index_t col = _nonZeroColsPtr[i];
        if(_matrix.colLengthsPtr[col] != 0) {
            _nonZeroColsPtr[writePos++] = col;
        }
    }
    _nonZeroColsCount = writePos;
}

- (void) computeLowAndLeftColByLow {
    NSLog(@"Start method computeLowAndLeftColByLow");
    [self ComputeLowOnGpu];
    
    for(index_t i = 0; i < _nonZeroColsCount;i++) {
        index_t col = _nonZeroColsPtr[i];
        index_t low = _lowPtr[col];
        if(low != MAX_INDEX && _leftColByLowPtr[low] > col) {
            _leftColByLowPtr[low] = col;
        }
    }
}

//- (void) MakeClearing{
//    NSLog(@"Start method MakeClearing");
//    index_t cleared = 0;
//    for(index_t col = 0; col < _matrix.n; col++) {
//        index_t colToZero = _lowPtr[col];
//        if(colToZero == MAX_INDEX) {
//            continue;
//        }
//        if(_matrix.colLengthsPtr[colToZero] == 0) {
//            continue;
//        }
//        cleared++;
//        _lowPtr[colToZero] = MAX_INDEX;
//        _matrix.colLengthsPtr[colToZero] = 0;
//    }
//    NSLog(@"Cleared columns: %u", cleared);
//}

- (void) computeColToAdd {
    NSLog(@"Start method computeColToAdd");
    for(index_t col = 0; col < _matrix.n; col++) {
        index_t low = _lowPtr[col];
        if(low == MAX_INDEX) {
            _colToAddPtr[col] = MAX_INDEX;
            continue;
        }
        index_t left_col_by_low = _leftColByLowPtr[low];
        if(left_col_by_low == col) {
            _colToAddPtr[col] = MAX_INDEX;
        } else {
            _colToAddPtr[col] = left_col_by_low;
        }
    }
}

- (bool) isMatrixReduced {
    for(index_t col = 0; col < _matrix.n; col++) {
        index_t low = _lowPtr[col];
        if(low == MAX_INDEX) {
            continue;
        }
        if(_leftColByLowPtr[low] != col) {
            return false;
        }
    }
    return true;
}

- (void) addColumns {
    NSLog(@"Start method addColumns");
    index_t add_cnt = 0;
    for(index_t col = 0; col < _matrix.n; col++) {
        _matrixToSumCols.colLengthsPtr[col] = _matrix.colLengthsPtr[col];
        index_t colToAdd = _colToAddPtr[col];
        if(colToAdd != MAX_INDEX) {
            _matrixToSumCols.colLengthsPtr[col] += _matrix.colLengthsPtr[colToAdd] - 2;
            add_cnt++;
        }
    }
    
    NSLog(@"ADD TASKS=%u", add_cnt);
    
    for(index_t col = 1; col < _matrix.n; col++) {
        _matrixToSumCols.colOffsetsPtr[col] = _matrixToSumCols.colOffsetsPtr[col - 1] + _matrixToSumCols.colLengthsPtr[col - 1];
    }
    
    index_t maxNonZeros = _matrixToSumCols.colOffsetsPtr[_matrix.n - 1] + _matrixToSumCols.colLengthsPtr[_matrix.n - 1];
    unsigned long minBufSize = maxNonZeros * sizeof(index_t);
    if(minBufSize > _matrixToSumCols.rowIndices.length){
        _matrixToSumCols.rowIndices = [_mDevice newBufferWithLength:minBufSize*2 options:MTLResourceStorageModeShared];
        NSLog(@"MAKE ALLOCATION %lu", minBufSize*2);
    }
    
    [self ExecuteColumnAdditionsOnGpu];
    
    // swap
    SparseMatrix *tmp = _matrix;
    _matrix = _matrixToSumCols;
    _matrixToSumCols = tmp;
}
    
- (void) ExecuteColumnAdditionsOnGpu {
//    NSDate *methodStart = [NSDate date];
//    for(uint col = 0; col < _matrix.n;col++){
//        addMatrixColumns2(_matrix.colOffsetsPtr, _matrix.colLengthsPtr, _matrix.rowIndicesPtr,
//                      _matrixToSumCols.colOffsetsPtr, _matrixToSumCols.colLengthsPtr, _matrixToSumCols.rowIndicesPtr,
//                      _colToAddPtr, col);
//    }
//    NSDate *methodFinish = [NSDate date];
//    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
//    NSLog(@"CPU_EXECUTION_TIME = %f", 1000 * executionTime);
//    _colAdditionsGPUTime += executionTime;


    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    assert(commandBuffer != nil);
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    assert(computeEncoder != nil);


//    [_matrix.colOffsets didModifyRange:NSMakeRange(0, _matrix.colOffsets.length)];
//    [_matrix.colLengths didModifyRange:NSMakeRange(0, _matrix.colLengths.length)];
//    [_matrix.rowIndices didModifyRange:NSMakeRange(0, _matrix.rowIndices.length)];
//    [_matrixToSumCols.colOffsets didModifyRange:NSMakeRange(0, _matrixToSumCols.colOffsets.length)];
//    [_matrixToSumCols.colLengths didModifyRange:NSMakeRange(0, _matrixToSumCols.colLengths.length)];
//    [_matrixToSumCols.rowIndices didModifyRange:NSMakeRange(0, _matrixToSumCols.rowIndices.length)];

    [computeEncoder setComputePipelineState:_mAddMatrixColumnsPSO];
    [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
    [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
    [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
    [computeEncoder setBuffer:_matrixToSumCols.colOffsets offset:0 atIndex:3];
    [computeEncoder setBuffer:_matrixToSumCols.colLengths offset:0 atIndex:4];
    [computeEncoder setBuffer:_matrixToSumCols.rowIndices offset:0 atIndex:5];
    [computeEncoder setBuffer:_colToAdd offset:0 atIndex:6];


    MTLSize gridSize = MTLSizeMake(_matrix.n, 1, 1);


    NSUInteger threadsInThreadgroup = MIN(_mAddMatrixColumnsPSO.maxTotalThreadsPerThreadgroup, _matrix.n);
    MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

    [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
    [computeEncoder endEncoding];

//    // Synchronize the managed buffer.
//    id <MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
//    [blitCommandEncoder synchronizeResource:_matrixToSumCols.colOffsets];
//    [blitCommandEncoder synchronizeResource:_matrixToSumCols.colLengths];
//    [blitCommandEncoder synchronizeResource:_matrixToSumCols.rowIndices];
//    [blitCommandEncoder endEncoding];


    NSDate *methodStart = [NSDate date];

    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"GPU_EXECUTION_TIME = %f", 1000 * executionTime);
    _colAdditionsGPUTime += executionTime;
}


- (void) ComputeLowOnGpu {
    NSLog(@"Start method ComputeLowOnGpu");
    NSDate *methodStart = [NSDate date];
    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    assert(commandBuffer != nil);
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    assert(computeEncoder != nil);


//    [_matrix.colOffsets didModifyRange:NSMakeRange(0, _matrix.colOffsets.length)];
//    [_matrix.colLengths didModifyRange:NSMakeRange(0, _matrix.colLengths.length)];
//    [_matrix.rowIndices didModifyRange:NSMakeRange(0, _matrix.rowIndices.length)];

    [computeEncoder setComputePipelineState:_mComputeLowPSO];
    [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
    [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
    [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
    [computeEncoder setBuffer:_low offset:0 atIndex:3];
    [computeEncoder setBuffer:_leftColByLow offset:0 atIndex:4];


    MTLSize gridSize = MTLSizeMake(_matrix.n, 1, 1);


    NSUInteger threadsInThreadgroup = MIN(_mAddMatrixColumnsPSO.maxTotalThreadsPerThreadgroup, _matrix.n);
    MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

    [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
    [computeEncoder endEncoding];

    NSLog(@"commandBuffer commit");
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"ComputeLowOnGpu execution time = %f", 1000 * executionTime);
    _colAdditionsGPUTime += executionTime;
}


@end
