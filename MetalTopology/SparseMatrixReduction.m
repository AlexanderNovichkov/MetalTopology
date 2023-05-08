#import "SparseMatrixReduction.h"

#include <stdint.h>

void addMatrixColumns2(const uint32_t *matrixColOffsets,
                               const uint32_t *matrixColLengths,
                               const uint32_t *matrixRowIndices,
                               const uint32_t *resultMatrixColOffsets,
                               uint32_t *resultMatrixColLengths,
                               uint32_t *resultMatrixRowIndices,
                               const uint32_t * colToAdd,
                               uint32_t rightCol)
{
    const uint32_t leftCol = colToAdd[rightCol];
    
    uint32_t leftColOffsetCur = (leftCol == __UINT32_MAX__) ? __UINT32_MAX__ : matrixColOffsets[leftCol];
    const uint32_t leftColOffsetEnd = (leftCol == __UINT32_MAX__) ? __UINT32_MAX__ : (leftColOffsetCur + matrixColLengths[leftCol]);
    
    uint32_t rightColOffsetCur = matrixColOffsets[rightCol];
    const uint32_t rightColOffsetEnd = rightColOffsetCur + matrixColLengths[rightCol];
    
    uint32_t resultColOffsetCur = resultMatrixColOffsets[rightCol];
    
    while (leftColOffsetCur < leftColOffsetEnd || rightColOffsetCur < rightColOffsetEnd) {
        uint32_t leftRow = (leftColOffsetCur < leftColOffsetEnd) ? matrixRowIndices[leftColOffsetCur] : __UINT32_MAX__;
        uint32_t rightRow = (rightColOffsetCur < rightColOffsetEnd) ? matrixRowIndices[rightColOffsetCur] : __UINT32_MAX__;
        
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
    
    // metrics
    double _colAdditionsGPUTime;
    
    // State variables, updated every iteration of algorithm
    SparseMatrix * _matrix;
    
    id<MTLBuffer> _low;
    uint32_t* _lowPtr;
    
    uint32_t _nonZeroColsCount;
    id<MTLBuffer> _nonZeroCols;
    uint32_t* _nonZeroColsPtr;
    
    id<MTLBuffer> _leftColByLow;
    uint32_t* _leftColByLowPtr;
    
    
    // Optimization variables, allow us not to allocate memory every iteration
    SparseMatrix * _matrixToSumCols;
    
    id<MTLBuffer> _colToAdd;
    uint32_t* _colToAddPtr;

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
        
        _mCommandQueue = [_mDevice newCommandQueue];
        if (_mCommandQueue == nil)
        {
            NSLog(@"Failed to find the command queue.");
            return nil;
        }
        
        _matrix = matrix;
        _matrixToSumCols = [[SparseMatrix alloc] initWithDevice: _mDevice N:_matrix.n];
        
        _nonZeroColsCount = 0;
        _nonZeroCols = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _nonZeroColsPtr = _nonZeroCols.contents;
        for(uint32_t col = 0; col < _matrix.n; col++) {
            if(_matrix.colLengthsPtr[col] != 0) {
                _nonZeroColsPtr[_nonZeroColsCount++] = col;
            }
        }
        
        _low = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _lowPtr = _low.contents;
        _leftColByLow = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _leftColByLowPtr = _leftColByLow.contents;
        for(uint32_t col = 0; col < _matrix.n; col++) {
            _leftColByLowPtr[col] = UINT32_MAX;
        }
        for(uint32_t col = 0; col < _matrix.n; col++) {
            uint32_t length = _matrix.colLengthsPtr[col];
            if(length == 0) {
                _lowPtr[col] = UINT32_MAX;
            } else {
                uint32_t offset = _matrix.colOffsetsPtr[col];
                uint32_t low = _matrix.rowIndicesPtr[offset + length - 1];
                _lowPtr[col] = low;
                if(_leftColByLowPtr[low] > col) {
                    _leftColByLowPtr[low] = col;
                }
            }
        }
        
        _colToAdd = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _colToAddPtr = _colToAdd.contents;
    }
    
    return self;
}

- (SparseMatrix*) makeReduction
{
    
//    [self MakeClearing];
    uint32_t it = 0;
    while (true){
        @autoreleasepool {
            it++;
            NSLog(@"Iteration start: %u", it);
            
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
    uint32_t writePos = 0;
    for(uint32_t i = 0; i < _nonZeroColsCount;i++) {
        uint32_t col = _nonZeroColsPtr[i];
        if(_matrix.colLengthsPtr[col] != 0) {
            _nonZeroColsPtr[writePos++] = col;
        }
    }
    _nonZeroColsCount = writePos;
}

- (void) computeLowAndLeftColByLow {
    NSLog(@"Start method computeLowAndLeftColByLow");
    for(uint32_t i = 0; i < _nonZeroColsCount;i++) {
        uint32_t col = _nonZeroColsPtr[i];
        uint32_t length = _matrix.colLengthsPtr[col];
        if(length == 0) {
            _lowPtr[col] = UINT32_MAX;
        } else {
            uint32_t offset = _matrix.colOffsetsPtr[col];
            uint32_t low = _matrix.rowIndicesPtr[offset + length - 1];
            _lowPtr[col] = low;
            if(_leftColByLowPtr[low] > col) {
                _leftColByLowPtr[low] = col;
            }
        }
    }
}

- (void) MakeClearing{
    NSLog(@"Start method MakeClearing");
    uint32_t cleared = 0;
    for(uint32_t col = 0; col < _matrix.n; col++) {
        uint32_t colToZero = _lowPtr[col];
        if(colToZero == UINT32_MAX) {
            continue;
        }
        if(_matrix.colLengthsPtr[colToZero] == 0) {
            continue;
        }
        cleared++;
        _lowPtr[colToZero] = UINT32_MAX;
        _matrix.colLengthsPtr[colToZero] = 0;
    }
    NSLog(@"Cleared columns: %u", cleared);
}

- (void) computeColToAdd {
    NSLog(@"Start method computeColToAdd");
    for(uint32_t col = 0; col < _matrix.n; col++) {
        uint32_t low = _lowPtr[col];
        if(low == UINT32_MAX) {
            _colToAddPtr[col] = UINT32_MAX;
            continue;
        }
        uint32_t left_col_by_low = _leftColByLowPtr[low];
        if(left_col_by_low == col) {
            _colToAddPtr[col] = UINT32_MAX;
        } else {
            _colToAddPtr[col] = left_col_by_low;
        }
    }
}

- (bool) isMatrixReduced {
    for(uint32_t col = 0; col < _matrix.n; col++) {
        uint32_t low = _lowPtr[col];
        if(low == UINT32_MAX) {
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
    uint32_t add_cnt = 0;
    for(uint32_t col = 0; col < _matrix.n; col++) {
        _matrixToSumCols.colLengthsPtr[col] = _matrix.colLengthsPtr[col];
        uint32_t colToAdd = _colToAddPtr[col];
        if(colToAdd != UINT32_MAX) {
            _matrixToSumCols.colLengthsPtr[col] += _matrix.colLengthsPtr[colToAdd] - 2;
            add_cnt++;
        }
    }
    
    NSLog(@"ADD TASKS=%lu", add_cnt);
    
    for(uint32_t col = 1; col < _matrix.n; col++) {
        _matrixToSumCols.colOffsetsPtr[col] = _matrixToSumCols.colOffsetsPtr[col - 1] + _matrixToSumCols.colLengthsPtr[col - 1];
    }
    
    uint32_t maxNonZeros = _matrixToSumCols.colOffsetsPtr[_matrix.n - 1] + _matrixToSumCols.colLengthsPtr[_matrix.n - 1];
    uint32_t minBufSize = maxNonZeros * sizeof(uint32_t);
    if(minBufSize > _matrixToSumCols.rowIndices.length){
        _matrixToSumCols.rowIndices = [_mDevice newBufferWithLength:minBufSize*2 options:MTLResourceStorageModeManaged];
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


    [_matrix.colOffsets didModifyRange:NSMakeRange(0, _matrix.colOffsets.length)];
    [_matrix.colLengths didModifyRange:NSMakeRange(0, _matrix.colLengths.length)];
    [_matrix.rowIndices didModifyRange:NSMakeRange(0, _matrix.rowIndices.length)];

    [_matrixToSumCols.colOffsets didModifyRange:NSMakeRange(0, _matrixToSumCols.colOffsets.length)];
    [_matrixToSumCols.colLengths didModifyRange:NSMakeRange(0, _matrixToSumCols.colLengths.length)];
    [_matrixToSumCols.rowIndices didModifyRange:NSMakeRange(0, _matrixToSumCols.rowIndices.length)];


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

    // Synchronize the managed buffer.
    id <MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
    [blitCommandEncoder synchronizeResource:_matrixToSumCols.colOffsets];
    [blitCommandEncoder synchronizeResource:_matrixToSumCols.colLengths];
    [blitCommandEncoder synchronizeResource:_matrixToSumCols.rowIndices];
    [blitCommandEncoder endEncoding];


    NSDate *methodStart = [NSDate date];

    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"GPU_EXECUTION_TIME = %f", 1000 * executionTime);
    _colAdditionsGPUTime += executionTime;
}




@end
