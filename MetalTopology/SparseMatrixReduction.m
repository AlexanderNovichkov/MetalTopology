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
    id<MTLDevice> _mDevice;
    id<MTLCommandQueue> _mCommandQueue;
    id<MTLComputePipelineState> _mAddMatrixColumnsPSO;
    
    // variables below are updated every iteration of algorithm
    SparseMatrix * _matrix;
    SparseMatrix * _matrixToSumCols;
    
    id<MTLBuffer> _low;
    uint32_t* _lowPtr;
    
    id<MTLBuffer> _leftColByLow;
    uint32_t* _leftColByLowPtr;
    
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
        
        _low = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _lowPtr = _low.contents;
        
        _leftColByLow = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _leftColByLowPtr = _leftColByLow.contents;
        
        _colToAdd = [_mDevice newBufferWithLength:matrix.n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        _colToAddPtr = _colToAdd.contents;
    }
    
    return self;
}

- (SparseMatrix*) makeReduction
{
    while (true){
        NSLog(@"Matrix at iteration start");
//        NSLog(@"%@", [_matrix description]);
        
        [self computeLow];
        NSLog(@"_lowPtr");
//        for(uint32_t col = 0; col < _matrix.n;col++) {
//            NSLog(@"%lu ", _lowPtr[col]);
//        }
        
        [self computeLeftColByLow];
        NSLog(@"_leftColByLowPtr");
//        for(uint32_t col = 0; col < _matrix.n;col++) {
//            NSLog(@"%lu ", _leftColByLowPtr[col]);
//        }
        
        if( [self isMatrixReduced]) {
            break;
        }
        
        [self computeColToAdd];
        NSLog(@"_colToAddPtr");
//        for(uint32_t col = 0; col < _matrix.n;col++) {
//            NSLog(@"%lu ", _colToAddPtr[col]);
//        }
        
        
        [self addColumns];
//        NSLog(@"%@", [_matrix description]);
        
        NSLog(@"Done Iteration");
    }
    return _matrix;
}


- (void) ExecuteColumnAdditionsOnGpu {
//    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
//    assert(commandBuffer != nil);
//    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
//    assert(computeEncoder != nil);

    for(uint col = 0; col < _matrix.n;col++){
        addMatrixColumns2(_matrix.colOffsetsPtr, _matrix.colLengthsPtr, _matrix.rowIndicesPtr,
                      _matrixToSumCols.colOffsetsPtr, _matrixToSumCols.colLengthsPtr, _matrixToSumCols.rowIndicesPtr,
                      _colToAddPtr, col);
    }
//    [computeEncoder setComputePipelineState:_mAddMatrixColumnsPSO];
//    [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
//    [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
//    [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
//    [computeEncoder setBuffer:_matrixToSumCols.colOffsets offset:0 atIndex:3];
//    [computeEncoder setBuffer:_matrixToSumCols.colLengths offset:0 atIndex:4];
//    [computeEncoder setBuffer:_matrixToSumCols.rowIndices offset:0 atIndex:5];
//    [computeEncoder setBuffer:_colToAdd offset:0 atIndex:6];
//
//
//    MTLSize gridSize = MTLSizeMake(_matrix.n, 1, 1);
//
//
//    NSUInteger threadsInThreadgroup = MIN(_mAddMatrixColumnsPSO.maxTotalThreadsPerThreadgroup, _matrix.n);
//    MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);
//
//    [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
//
//    [computeEncoder endEncoding];
//    [commandBuffer commit];
//    [commandBuffer waitUntilCompleted];
//
}

- (void) computeLow {
    for(uint32_t col = 0; col < _matrix.n; col++) {
        uint32_t length = _matrix.colLengthsPtr[col];
        if(length == 0) {
            _lowPtr[col] = UINT32_MAX;
        } else {
            uint32_t offset = _matrix.colOffsetsPtr[col];
            _lowPtr[col] = _matrix.rowIndicesPtr[offset + length - 1];
        }
    }
}

- (void) computeLeftColByLow {
    for(uint32_t col = 0; col < _matrix.n; col++) {
        _leftColByLowPtr[col] = UINT32_MAX;
    }
    for(uint32_t col = 0; col < _matrix.n; col++) {
        uint32_t low = _lowPtr[col];
        if(low == UINT32_MAX) {
            continue;
        }
        if(_leftColByLowPtr[low] > col) {
            _leftColByLowPtr[low] = col;
        }
    }
}

- (void) computeColToAdd {
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
    uint32_t add_cnt = 0;
    for(uint32_t col = 0; col < _matrix.n; col++) {
        _matrixToSumCols.colLengthsPtr[col] = _matrix.colLengthsPtr[col];
        uint32_t colToAdd = _colToAddPtr[col];
        if(colToAdd != UINT32_MAX) {
            _matrixToSumCols.colLengthsPtr[col] += _matrix.colLengthsPtr[colToAdd];
            add_cnt++;
            // TODO: вроде, можно гарантировать, что длина на 2 меньше
        }
    }
    
    NSLog(@"ADD TASKS=%lu", add_cnt);
    
    for(uint32_t col = 1; col < _matrix.n; col++) {
        _matrixToSumCols.colOffsetsPtr[col] = _matrixToSumCols.colOffsetsPtr[col - 1] + _matrixToSumCols.colLengthsPtr[col - 1];
    }
    
    uint32_t capacity = _matrixToSumCols.colOffsetsPtr[_matrix.n - 1] + _matrixToSumCols.colLengthsPtr[_matrix.n - 1];
    
    _matrixToSumCols.rowIndices = [_mDevice newBufferWithLength: capacity * sizeof(uint32_t) options:MTLResourceStorageModeShared];
    // TODO: Переиспользовать старый буффер, если его capacity >= нужного
    
    [self ExecuteColumnAdditionsOnGpu];
    
    // swap
    SparseMatrix *tmp = _matrix;
    _matrix = _matrixToSumCols;
    _matrixToSumCols = tmp;
}
    




@end
