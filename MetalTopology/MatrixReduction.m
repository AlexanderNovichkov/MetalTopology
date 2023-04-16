#import "MatrixReduction.h"


@implementation MatrixReduction
{
    id<MTLDevice> _mDevice;
    
    id<MTLComputePipelineState> _mAddFunctionPSO;
    
    id<MTLCommandQueue> _mCommandQueue;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device
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
        
        id<MTLFunction> addFunction = [defaultLibrary newFunctionWithName:@"add_arrays"];
        if (addFunction == nil)
        {
            NSLog(@"Failed to find the adder function.");
            return nil;
        }
        
        
        _mAddFunctionPSO = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
        if (_mAddFunctionPSO == nil)
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
    }
    
    return self;
}

- (void) makeReduction: (Matrix*) matrix;
{
    if(matrix.rows == 0) {
        return;
    }
    
    id<MTLBuffer> columnToAdd = [_mDevice newBufferWithLength:matrix.cols * sizeof(uint) options:MTLResourceStorageModeShared];
    uint* columnToAddPtr = columnToAdd.contents;
    id<MTLBuffer> columnAddTo = [_mDevice newBufferWithLength:matrix.cols * sizeof(uint) options:MTLResourceStorageModeShared];
    uint* columnAddToPtr = columnAddTo.contents;
    int AddColumnTasks = 0;
    
    NSMutableArray *lowestNonZero = [NSMutableArray arrayWithCapacity:matrix.cols];
    NSMutableArray *rowToFirstCol = [NSMutableArray arrayWithCapacity:matrix.rows];
    
    for(int row = 0; row < matrix.rows; row ++) {
        [rowToFirstCol addObject: [NSNumber numberWithInt: matrix.cols]];
    }
    for(int col = 0; col < matrix.cols; col++) {
        [lowestNonZero addObject: [NSNumber numberWithInt: matrix.rows-1]];
    }
    
    
    while (true){
        AddColumnTasks = 0;
        for(int col = 0; col < matrix.cols; col++) {
            int lowRow = [lowestNonZero[col] intValue];
            lowRow = [self getLowestNonZeroForMatix:matrix Col:col SearchAboveRow:lowRow];
            lowestNonZero[col] = [NSNumber numberWithInt: lowRow];
            if(lowRow == -1) {
                continue;
            }
            
            if([rowToFirstCol[lowRow] intValue] >= col) {
                rowToFirstCol[lowRow] = [NSNumber numberWithInt:col];
                continue;
            }
            
            columnToAddPtr[AddColumnTasks] = [matrix getDataBufferOffsetForCol:
                                                [rowToFirstCol[lowRow] intValue] ];
            columnAddToPtr[AddColumnTasks] = [matrix getDataBufferOffsetForCol: col];
            AddColumnTasks++;
        }
        
        if(AddColumnTasks == 0) {
            break;
        }
        
        
        [self ExecuteColumnAdditionsWithMatrix:matrix ColumnToAdd:columnToAdd ColumnAddTo:columnAddTo AddColumnTasks:AddColumnTasks];
        
    }
}

- (int) getLowestNonZeroForMatix: (Matrix *) matrix Col: (int) col SearchAboveRow: (int) searchAboveRow
{
    for(int row = searchAboveRow; row >=0; row--) {
        if([matrix getRow:row Col:col]) {
            return row;
        }
    }
    return -1;
}

//- (void) ExecuteColumnAdditionsWithMatrix: (Matrix*) matrix
//                           ColumnToAddPtr:(uint*) columnToAddPtr
//                           ColumnAddToPtr: (uint*) columnAddToPtr
//                         AddColumnTasks: (int) AddColumnTasks {
//    for(int i = 0; i < AddColumnTasks;i++) {
//        uint toAdd = columnToAddPtr[i];
//        uint addTo = columnAddToPtr[i];
//        for(uint row = 0; row < matrix.rows; row++) {
//            bool new_val = [matrix getRow:row Col:toAdd] != [matrix getRow:row Col:addTo];
//            [matrix setRow:row Col:addTo Val:new_val];
//        }
//    }
//
//}

- (void) ExecuteColumnAdditionsWithMatrix: (Matrix*) matrix
                           ColumnToAdd: (id<MTLBuffer>) columnToAdd
                           ColumnAddTo: (id<MTLBuffer>) columnAddTo
                         AddColumnTasks: (int) AddColumnTasks {
    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    assert(commandBuffer != nil);
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    assert(computeEncoder != nil);

    [computeEncoder setComputePipelineState:_mAddFunctionPSO];
    [computeEncoder setBuffer:columnToAdd offset:0 atIndex:0];
    [computeEncoder setBuffer:columnAddTo offset:0 atIndex:1];
    [computeEncoder setBuffer: matrix.dataBuffer offset:0 atIndex:2];
    

    MTLSize gridSize = MTLSizeMake(AddColumnTasks, matrix.rows, 1);


    NSUInteger threadGroupSize = _mAddFunctionPSO.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > AddColumnTasks)
    {
        threadGroupSize = AddColumnTasks;
    }
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    
    [computeEncoder dispatchThreads:gridSize
              threadsPerThreadgroup:threadgroupSize];
    

    [computeEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
}
@end
