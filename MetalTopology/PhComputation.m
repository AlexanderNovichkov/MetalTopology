#import "PhComputation.h"

#import <stdint.h>
#import "Types.h"

void swapIndexPtrs(index_t **ptrA, index_t **ptrB) {
  index_t *temp = *ptrA;
  *ptrA = *ptrB;
  *ptrB = temp;
}

void swapMatrixPtrs(SparseMatrix *__strong *ptrA, SparseMatrix *__strong *ptrB) {
  SparseMatrix *temp = *ptrA;
  *ptrA = *ptrB;
  *ptrB = temp;
}

@implementation PhComputation {
  // metal variables
  id<MTLDevice> _mDevice;
  id<MTLCommandQueue> _mCommandQueue;
  id<MTLComputePipelineState> _mMakeInitialClearingPSO;
  id<MTLComputePipelineState> _mInitNonZeroColsPSO;
  id<MTLComputePipelineState> _mFillLeftColByLowPSO;
  id<MTLComputePipelineState> _mInitLowAndLeftColByLowPSO;
  id<MTLComputePipelineState> _mExecuteLeftRightAdditionsPSO;
  id<MTLComputePipelineState> _mComputeLowAndLeftColByLowPSO;
  id<MTLComputePipelineState> _mComputeNonZeroColsPSO;
  id<MTLComputePipelineState> _mComputeLeftColsAndLeftRightPairsPSO;
  id<MTLComputePipelineState> _mComputeMatrixColLengthsPSO;
  id<MTLComputePipelineState> _mCopyLeftColumnsPSO;
  id<MTLComputePipelineState> _mComputeMatrixOffsetsBlockSumsPSO;
  id<MTLComputePipelineState> _mComputeMatrixOffsetsPSO;

  // State variables, updated every iteration of algorithm
  SparseMatrix *_matrix;

  id<MTLBuffer> _low;
  index_t *_lowPtr;
  id<MTLBuffer> _leftColByLow;
  index_t *_leftColByLowPtr;

  id<MTLBuffer> _nonZeroColsCount;
  index_t *_nonZeroColsCountPtr;
  id<MTLBuffer> _nonZeroCols;
  index_t *_nonZeroColsPtr;

  id<MTLBuffer> _leftColsCount;
  index_t *_leftColsCountPtr;
  id<MTLBuffer> _leftCols;
  index_t *_leftColsPtr;

  id<MTLBuffer> _leftRightPairsCount;
  index_t *_leftRightPairsCountPtr;
  id<MTLBuffer> _leftRightPairs;
  struct LeftRightPair *_leftRightPairsPtr;

  // Optimization variables, allow us not to allocate memory every iteration
  SparseMatrix *_matrixToSumCols;
  id<MTLBuffer> _nonZeroColsResult;
  index_t *_nonZeroColsResultPtr;

  index_t _matrixOffsetsBlocksCount;
  id<MTLBuffer> _matrixOffsetsBlockSums;
  index_t *_matrixOffsetsBlockSumsPtr;

  id<MTLBuffer> _matrixSize;
  index_t *_matrixNPtr;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device Matrix:(SparseMatrix *)matrix {
  self = [super init];
  if (self) {
    _mDevice = device;

    NSError *error = nil;

    id<MTLLibrary> defaultLibrary =
        [_mDevice newDefaultLibraryWithBundle:[NSBundle bundleForClass:[self class]] error:nil];
    if (defaultLibrary == nil) {
      NSLog(@"Failed to find the default library.");
      return nil;
    }

    id<MTLFunction> makeInitialClearing =
        [defaultLibrary newFunctionWithName:@"makeInitialClearing"];
    if (makeInitialClearing == nil) {
      NSLog(@"Failed to find metal function makeClearing");
      return nil;
    }
    _mMakeInitialClearingPSO = [_mDevice newComputePipelineStateWithFunction:makeInitialClearing
                                                                       error:&error];
    if (_mMakeInitialClearingPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> initNonZeroCols = [defaultLibrary newFunctionWithName:@"initNonZeroCols"];
    if (initNonZeroCols == nil) {
      NSLog(@"Failed to find metal function InitNonZeroCols");
      return nil;
    }
    _mInitNonZeroColsPSO = [_mDevice newComputePipelineStateWithFunction:initNonZeroCols
                                                                   error:&error];
    if (_mInitNonZeroColsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> fillLeftColByLow = [defaultLibrary newFunctionWithName:@"fillLeftColByLow"];
    if (fillLeftColByLow == nil) {
      NSLog(@"Failed to find metal function fillLeftColByLow");
      return nil;
    }
    _mFillLeftColByLowPSO = [_mDevice newComputePipelineStateWithFunction:fillLeftColByLow
                                                                    error:&error];
    if (_mFillLeftColByLowPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> initLowAndLeftColByLow =
        [defaultLibrary newFunctionWithName:@"initLowAndLeftColByLow"];
    if (initLowAndLeftColByLow == nil) {
      NSLog(@"Failed to find metal function initLowAndLeftColByLow");
      return nil;
    }
    _mInitLowAndLeftColByLowPSO =
        [_mDevice newComputePipelineStateWithFunction:initLowAndLeftColByLow error:&error];
    if (_mInitLowAndLeftColByLowPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> executeLeftRightAdditions =
        [defaultLibrary newFunctionWithName:@"executeLeftRightAdditions"];
    if (executeLeftRightAdditions == nil) {
      NSLog(@"Failed to find metal function addMatrixColumns");
      return nil;
    }
    _mExecuteLeftRightAdditionsPSO =
        [_mDevice newComputePipelineStateWithFunction:executeLeftRightAdditions error:&error];
    if (_mExecuteLeftRightAdditionsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> computeLowAndLeftColByLow =
        [defaultLibrary newFunctionWithName:@"computeLowAndLeftColByLow"];
    if (computeLowAndLeftColByLow == nil) {
      NSLog(@"Failed to find metal function computeLow");
      return nil;
    }
    _mComputeLowAndLeftColByLowPSO =
        [_mDevice newComputePipelineStateWithFunction:computeLowAndLeftColByLow error:&error];
    if (_mComputeLowAndLeftColByLowPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> computeNonZeroCols = [defaultLibrary newFunctionWithName:@"computeNonZeroCols"];
    if (computeNonZeroCols == nil) {
      NSLog(@"Failed to find metal function computeLow");
      return nil;
    }
    _mComputeNonZeroColsPSO = [_mDevice newComputePipelineStateWithFunction:computeNonZeroCols
                                                                      error:&error];
    if (_mComputeNonZeroColsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> computeLeftColsAndLeftRightPairs =
        [defaultLibrary newFunctionWithName:@"computeLeftColsAndLeftRightPairs"];
    if (computeLeftColsAndLeftRightPairs == nil) {
      NSLog(@"Failed to find metal function computeLow");
      return nil;
    }
    _mComputeLeftColsAndLeftRightPairsPSO =
        [_mDevice newComputePipelineStateWithFunction:computeLeftColsAndLeftRightPairs
                                                error:&error];
    if (_mComputeLeftColsAndLeftRightPairsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> computeMatrixColLengths =
        [defaultLibrary newFunctionWithName:@"computeMatrixColLengths"];
    if (computeMatrixColLengths == nil) {
      NSLog(@"Failed to find metal function computeLow");
      return nil;
    }
    _mComputeMatrixColLengthsPSO =
        [_mDevice newComputePipelineStateWithFunction:computeMatrixColLengths error:&error];
    if (_mComputeMatrixColLengthsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> copyLeftColumns = [defaultLibrary newFunctionWithName:@"copyLeftColumns"];
    if (copyLeftColumns == nil) {
      NSLog(@"Failed to find metal function copyLeftColumns");
      return nil;
    }
    _mCopyLeftColumnsPSO = [_mDevice newComputePipelineStateWithFunction:copyLeftColumns
                                                                   error:&error];
    if (_mCopyLeftColumnsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> computeMatrixOffsetsBlockSums =
        [defaultLibrary newFunctionWithName:@"computeMatrixOffsetsBlockSums"];
    if (computeMatrixOffsetsBlockSums == nil) {
      NSLog(@"Failed to find metal function computeMatrixOffsetsBlockSums");
      return nil;
    }
    _mComputeMatrixOffsetsBlockSumsPSO =
        [_mDevice newComputePipelineStateWithFunction:computeMatrixOffsetsBlockSums error:&error];
    if (_mComputeMatrixOffsetsBlockSumsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    id<MTLFunction> computeMatrixOffsets =
        [defaultLibrary newFunctionWithName:@"computeMatrixOffsets"];
    if (computeMatrixOffsets == nil) {
      NSLog(@"Failed to find metal function computeMatrixOffsets");
      return nil;
    }
    _mComputeMatrixOffsetsPSO = [_mDevice newComputePipelineStateWithFunction:computeMatrixOffsets
                                                                        error:&error];
    if (_mComputeMatrixOffsetsPSO == nil) {
      NSLog(@"Failed to created pipeline state object, error %@.", error);
      return nil;
    }

    _mCommandQueue = [_mDevice newCommandQueue];
    if (_mCommandQueue == nil) {
      NSLog(@"Failed to find the command queue.");
      return nil;
    }

    _matrix = matrix;

    _nonZeroColsCount = [_mDevice newBufferWithLength:sizeof(index_t)
                                              options:MTLResourceStorageModeShared];
    _nonZeroColsCountPtr = _nonZeroColsCount.contents;
    _nonZeroCols = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t)
                                         options:MTLResourceStorageModeShared];
    _nonZeroColsPtr = _nonZeroCols.contents;

    _low = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t)
                                 options:MTLResourceStorageModeShared];
    _lowPtr = _low.contents;
    _leftColByLow = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t)
                                          options:MTLResourceStorageModeShared];
    _leftColByLowPtr = _leftColByLow.contents;

    _leftColsCount = [_mDevice newBufferWithLength:sizeof(index_t)
                                           options:MTLResourceStorageModeShared];
    _leftColsCountPtr = _leftColsCount.contents;
    _leftCols = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t)
                                      options:MTLResourceStorageModeShared];
    _leftColsPtr = _leftCols.contents;

    _leftRightPairsCount = [_mDevice newBufferWithLength:sizeof(index_t)
                                                 options:MTLResourceStorageModeShared];
    _leftRightPairsCountPtr = _leftRightPairsCount.contents;
    _leftRightPairs = [_mDevice newBufferWithLength:matrix.n * sizeof(struct LeftRightPair)
                                            options:MTLResourceStorageModeShared];
    _leftRightPairsPtr = _leftRightPairs.contents;

    _matrixToSumCols = [[SparseMatrix alloc] initWithDevice:_mDevice N:_matrix.n nonZeros:1];

    _matrixOffsetsBlocksCount = (matrix.n + OFFSETS_BLOCK_SIZE - 1) / OFFSETS_BLOCK_SIZE;
    _matrixOffsetsBlockSums =
        [_mDevice newBufferWithLength:_matrixOffsetsBlocksCount * sizeof(index_t)
                              options:MTLResourceStorageModeShared];
    _matrixOffsetsBlockSumsPtr = _matrixOffsetsBlockSums.contents;

    _nonZeroColsResult = [_mDevice newBufferWithLength:matrix.n * sizeof(index_t)
                                               options:MTLResourceStorageModeShared];
    _nonZeroColsResultPtr = _nonZeroColsResult.contents;

    _matrixSize = [_mDevice newBufferWithLength:sizeof(index_t)
                                        options:MTLResourceStorageModeShared];
    *((index_t *)_matrixSize.contents) = matrix.n;
  }

  return self;
}

- (PersistencePairs *)getPersistentPairs {
  PersistencePairs *pairs = [[PersistencePairs alloc] init];
  for (index_t i = 0; i < *_nonZeroColsCountPtr; i++) {
    index_t col = _nonZeroColsPtr[i];
    PersistencePair *pair = [[PersistencePair alloc] init];
    pair.birth = _lowPtr[col];
    pair.death = col;
    [pairs.pairs addObject:pair];
  }
  [pairs sortPairsByBirth];
  return pairs;
}

- (SparseMatrix *)makeReduction {
  NSDate *start = [NSDate date];

  [self syncMatrixAndMakeInitialClearingOnGpu];
  [self initNonZeroColsOnGpu];
  [self initLowAndLeftColByLowOnGpu];

  index_t it = 0;
  while (true) {
    @autoreleasepool {
      it++;
      NSLog(@"Iteration start: %u", it);

      [self computeLeftColsAndLeftRightPairsOnGPU];

      if (*_leftRightPairsCountPtr == 0) {
        break;
      }

      [self makeLeftRightColsAdditions];

      [self computeLowAndLeftColByLowOnGpu];

      [self computeNonZeroColsOnGpu];
    }
  }

  _computationTimeTotal = [[NSDate date] timeIntervalSinceDate:start];

  return _matrix;
}

- (void)syncMatrixAndMakeInitialClearingOnGpu {
  NSLog(@"Start method syncMatrixAndMakeInitialClearingOnGpu");

  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  //  [_matrix.colOffsets didModifyRange:NSMakeRange(0, _matrix.colOffsets.length)];
  //  [_matrix.colLengths didModifyRange:NSMakeRange(0, _matrix.colLengths.length)];
  //  [_matrix.rowIndices didModifyRange:NSMakeRange(0, _matrix.rowIndices.length)];

  [computeEncoder setComputePipelineState:_mMakeInitialClearingPSO];
  [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
  MTLSize gridSize = MTLSizeMake(_matrix.n, 1, 1);

  NSUInteger threadsInThreadgroup =
      MIN(_mMakeInitialClearingPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];
}

- (void)initNonZeroColsOnGpu {
  NSLog(@"Start method initNonZeroColsOnGpu");
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  [computeEncoder setComputePipelineState:_mInitNonZeroColsPSO];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:0];
  [computeEncoder setBuffer:_nonZeroCols offset:0 atIndex:1];
  [computeEncoder setBuffer:_nonZeroColsCount offset:0 atIndex:2];

  MTLSize gridSize = MTLSizeMake(_matrix.n, 1, 1);

  NSUInteger threadsInThreadgroup =
      MIN(_mInitNonZeroColsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];
}

- (void)initLowAndLeftColByLowOnGpu {
  NSLog(@"Start method initLowAndLeftColByLowOnGpu");
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  [computeEncoder setComputePipelineState:_mFillLeftColByLowPSO];
  [computeEncoder setBuffer:_leftColByLow offset:0 atIndex:0];
  MTLSize gridSize = MTLSizeMake(_matrix.n, 1, 1);
  NSUInteger threadsInThreadgroup =
      MIN(_mFillLeftColByLowPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);
  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];

  [computeEncoder setComputePipelineState:_mInitLowAndLeftColByLowPSO];
  [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
  [computeEncoder setBuffer:_low offset:0 atIndex:3];
  [computeEncoder setBuffer:_leftColByLow offset:0 atIndex:4];
  [computeEncoder setBuffer:_nonZeroCols offset:0 atIndex:5];
  gridSize = MTLSizeMake(*_nonZeroColsCountPtr, 1, 1);
  threadsInThreadgroup =
      MIN(_mInitLowAndLeftColByLowPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);
  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];

  [computeEncoder endEncoding];
  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];
}

- (void)makeLeftRightColsAdditions {
  [self computeMatrixColLengthsOnGpu];
  [self computeMatrixColOffsets];
  [self computeMatrixRowIndices];
}

- (void)computeMatrixColOffsets {
  NSLog(@"Start method computeMatrixColOffsets");
  NSDate *start = [NSDate date];

  [self computeMatrixOffsetsBlockSumsOnGpu];

  for (index_t blockId = 1; blockId < _matrixOffsetsBlocksCount; blockId++) {
    _matrixOffsetsBlockSumsPtr[blockId] += _matrixOffsetsBlockSumsPtr[blockId - 1];
  }

  [self computeMatrixOffsetsOnGpu];

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"computeMatrixColOffsets execution time = %f", 1000 * executionTime);
  _computeMatrixColOffsetsTime += executionTime;
}

- (void)computeMatrixOffsetsBlockSumsOnGpu {
  NSLog(@"Start method computeMatrixOffsetsBlockSumsOnGpu");
  NSDate *start = [NSDate date];
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);

  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);
  [computeEncoder setComputePipelineState:_mComputeMatrixOffsetsBlockSumsPSO];
  [computeEncoder setBuffer:_matrixToSumCols.colLengths offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrixOffsetsBlockSums offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrixSize offset:0 atIndex:2];

  MTLSize gridSize = MTLSizeMake(_matrixOffsetsBlocksCount, 1, 1);
  NSUInteger threadsInThreadgroup =
      MIN(_mComputeMatrixOffsetsBlockSumsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"computeMatrixOffsetsBlockSumsOnGpu execution time = %f", 1000 * executionTime);
}

- (void)computeMatrixOffsetsOnGpu {
  NSLog(@"Start method computeMatrixOffsetsOnGpu");
  NSDate *start = [NSDate date];
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);

  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);
  [computeEncoder setComputePipelineState:_mComputeMatrixOffsetsPSO];
  [computeEncoder setBuffer:_matrixToSumCols.colLengths offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrixOffsetsBlockSums offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrixSize offset:0 atIndex:2];
  [computeEncoder setBuffer:_matrixToSumCols.colOffsets offset:0 atIndex:3];

  MTLSize gridSize = MTLSizeMake(_matrixOffsetsBlocksCount, 1, 1);
  NSUInteger threadsInThreadgroup =
      MIN(_mComputeMatrixOffsetsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"computeMatrixOffsetsOnGpu execution time = %f", 1000 * executionTime);
}

- (void)computeMatrixRowIndices {
  index_t maxNonZeros =
      _matrixToSumCols.colOffsetsPtr[_matrix.n - 1] + _matrixToSumCols.colLengthsPtr[_matrix.n - 1];
  unsigned long minBufSize = maxNonZeros * sizeof(index_t);
  if (minBufSize > _matrixToSumCols.rowIndices.length) {
    _matrixToSumCols.rowIndices = [_mDevice newBufferWithLength:minBufSize * 2
                                                        options:MTLResourceStorageModeShared];
    NSLog(@"MAKE ALLOCATION %lu", minBufSize * 2);
  }

  [self copyLeftColumnsOnGpu];
  [self executeLeftRightAdditionsOnGpu];

  swapMatrixPtrs(&_matrix, &_matrixToSumCols);
}

- (void)copyLeftColumnsOnGpu {
  NSLog(@"Start method copyLeftColumnsOnGpu");
  NSDate *start = [NSDate date];

  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  [computeEncoder setComputePipelineState:_mCopyLeftColumnsPSO];
  [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
  [computeEncoder setBuffer:_matrixToSumCols.colOffsets offset:0 atIndex:3];
  [computeEncoder setBuffer:_matrixToSumCols.rowIndices offset:0 atIndex:4];
  [computeEncoder setBuffer:_leftCols offset:0 atIndex:5];

  MTLSize gridSize = MTLSizeMake(*_leftColsCountPtr, 1, 1);

  NSUInteger threadsInThreadgroup =
      MIN(_mCopyLeftColumnsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"executeCopyLeftColumnsOnGpuTime execution time = %f", 1000 * executionTime);
  _executeCopyLeftColumnsOnGpuTime += executionTime;
}

- (void)executeLeftRightAdditionsOnGpu {
  NSLog(@"Start method ExecuteLeftRightAdditionsOnGpu");
  NSDate *start = [NSDate date];

  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  //    [_matrix.colOffsets didModifyRange:NSMakeRange(0, _matrix.colOffsets.length)];
  //    [_matrix.colLengths didModifyRange:NSMakeRange(0, _matrix.colLengths.length)];
  //    [_matrix.rowIndices didModifyRange:NSMakeRange(0, _matrix.rowIndices.length)];
  //    [_matrixToSumCols.colOffsets didModifyRange:NSMakeRange(0,
  //    _matrixToSumCols.colOffsets.length)];
  //    [_matrixToSumCols.colLengths didModifyRange:NSMakeRange(0,
  //    _matrixToSumCols.colLengths.length)];
  //    [_matrixToSumCols.rowIndices didModifyRange:NSMakeRange(0,
  //    _matrixToSumCols.rowIndices.length)];

  [computeEncoder setComputePipelineState:_mExecuteLeftRightAdditionsPSO];
  [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
  [computeEncoder setBuffer:_matrixToSumCols.colOffsets offset:0 atIndex:3];
  [computeEncoder setBuffer:_matrixToSumCols.colLengths offset:0 atIndex:4];
  [computeEncoder setBuffer:_matrixToSumCols.rowIndices offset:0 atIndex:5];
  [computeEncoder setBuffer:_leftRightPairs offset:0 atIndex:6];

  MTLSize gridSize = MTLSizeMake(*_leftRightPairsCountPtr, 1, 1);

  NSUInteger threadsInThreadgroup =
      MIN(_mExecuteLeftRightAdditionsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  //    // Synchronize the managed buffer.
  //    id <MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
  //    [blitCommandEncoder synchronizeResource:_matrixToSumCols.colOffsets];
  //    [blitCommandEncoder synchronizeResource:_matrixToSumCols.colLengths];
  //    [blitCommandEncoder synchronizeResource:_matrixToSumCols.rowIndices];
  //    [blitCommandEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"ExecuteLeftRightAdditions execution time = %f", 1000 * executionTime);
  _executeLeftRightAdditionsGpuTime += executionTime;
}

- (void)computeLeftColsAndLeftRightPairsOnGPU {
  NSLog(@"Start method computeLeftColsAndLeftRightPairsOnGPU");
  NSDate *start = [NSDate date];
  *_leftColsCountPtr = 0;
  *_leftRightPairsCountPtr = 0;

  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  [computeEncoder setComputePipelineState:_mComputeLeftColsAndLeftRightPairsPSO];
  [computeEncoder setBuffer:_low offset:0 atIndex:0];
  [computeEncoder setBuffer:_leftColByLow offset:0 atIndex:1];
  [computeEncoder setBuffer:_leftCols offset:0 atIndex:2];
  [computeEncoder setBuffer:_leftColsCount offset:0 atIndex:3];
  [computeEncoder setBuffer:_leftRightPairs offset:0 atIndex:4];
  [computeEncoder setBuffer:_leftRightPairsCount offset:0 atIndex:5];
  [computeEncoder setBuffer:_nonZeroCols offset:0 atIndex:6];

  MTLSize gridSize = MTLSizeMake(*_nonZeroColsCountPtr, 1, 1);

  NSUInteger threadsInThreadgroup =
      MIN(_mComputeLeftColsAndLeftRightPairsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSLog(@"leftColsCount=%u, leftRightPairsCount=%u", *_leftColsCountPtr, *_leftRightPairsCountPtr);

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"computeLeftAndRightColsGpuTime execution time = %f", 1000 * executionTime);
  _computeLeftColsAndLeftRightPairsGpuTime += executionTime;
}

- (void)computeMatrixColLengthsOnGpu {
  NSLog(@"Start method computeMatrixColLengthsOnGpu");
  NSDate *start = [NSDate date];
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);

  id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
  assert(blitCommandEncoder != nil);
  [blitCommandEncoder copyFromBuffer:_matrix.colLengths
                        sourceOffset:0
                            toBuffer:_matrixToSumCols.colLengths
                   destinationOffset:0
                                size:_matrix.colLengths.length];
  [blitCommandEncoder endEncoding];

  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);
  [computeEncoder setComputePipelineState:_mComputeMatrixColLengthsPSO];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrixToSumCols.colLengths offset:0 atIndex:1];
  [computeEncoder setBuffer:_leftRightPairs offset:0 atIndex:2];

  MTLSize gridSize = MTLSizeMake(*_leftRightPairsCountPtr, 1, 1);
  NSUInteger threadsInThreadgroup =
      MIN(_mComputeMatrixColLengthsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
  NSLog(@"computeMatrixColLengthsGpuTime execution time = %f", 1000 * executionTime);
  _computeMatrixColLengthsGpuTime += executionTime;
}

- (void)computeLowAndLeftColByLowOnGpu {
  NSLog(@"Start method ComputeLowOnGpu");
  NSDate *methodStart = [NSDate date];
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  [computeEncoder setComputePipelineState:_mComputeLowAndLeftColByLowPSO];
  [computeEncoder setBuffer:_matrix.colOffsets offset:0 atIndex:0];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:1];
  [computeEncoder setBuffer:_matrix.rowIndices offset:0 atIndex:2];
  [computeEncoder setBuffer:_low offset:0 atIndex:3];
  [computeEncoder setBuffer:_leftColByLow offset:0 atIndex:4];
  [computeEncoder setBuffer:_leftRightPairs offset:0 atIndex:5];

  MTLSize gridSize = MTLSizeMake(*_leftRightPairsCountPtr, 1, 1);

  NSUInteger threadsInThreadgroup =
      MIN(_mComputeLowAndLeftColByLowPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  NSDate *methodFinish = [NSDate date];
  NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
  NSLog(@"ComputeLowOnGpu execution time = %f", 1000 * executionTime);
  _computeLowAndLeftColByLowGPUTime += executionTime;
}

- (void)computeNonZeroColsOnGpu {
  NSLog(@"Start method ComputeLowOnGpu");
  NSDate *methodStart = [NSDate date];
  id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
  assert(commandBuffer != nil);
  id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
  assert(computeEncoder != nil);

  [computeEncoder setComputePipelineState:_mComputeNonZeroColsPSO];
  [computeEncoder setBuffer:_matrix.colLengths offset:0 atIndex:0];
  [computeEncoder setBuffer:_nonZeroCols offset:0 atIndex:1];
  [computeEncoder setBuffer:_nonZeroColsResult offset:0 atIndex:2];
  [computeEncoder setBuffer:_nonZeroColsCount offset:0 atIndex:3];

  MTLSize gridSize = MTLSizeMake(*_nonZeroColsCountPtr, 1, 1);
  (*_nonZeroColsCountPtr) = 0;

  NSUInteger threadsInThreadgroup =
      MIN(_mComputeNonZeroColsPSO.maxTotalThreadsPerThreadgroup, gridSize.width);
  MTLSize threadgroupSize = MTLSizeMake(threadsInThreadgroup, 1, 1);

  [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
  [computeEncoder endEncoding];

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];

  swapIndexPtrs(&_nonZeroColsPtr, &_nonZeroColsResultPtr);

  id<MTLBuffer> temp = _nonZeroCols;
  _nonZeroCols = _nonZeroColsResult;
  _nonZeroColsResult = temp;

  NSDate *methodFinish = [NSDate date];
  NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
  NSLog(@"computeNonZeroColsGPUTime execution time = %f", 1000 * executionTime);
  _computeNonZeroColsGPUTime += executionTime;
}

@end
