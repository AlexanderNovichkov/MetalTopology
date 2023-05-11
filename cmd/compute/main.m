#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "SparseMatrixReduction.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * path = @"/Users/alex/Desktop/Education/4-cource/diploma/MetalTopologyBenchmark/datasets/vr_boundary_matrices/hiv_4_700.0_metal.txt";

        id<MTLDevice> device = MTLCopyAllDevices()[1];
        NSLog([device name]);

        SparseMatrix *matrix = [[SparseMatrix alloc] initWithDevice:device FromFile:path];
        
        SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice: device Matrix:matrix];
        
        NSDate *start = [NSDate date];
        SparseMatrix *reducedMatrix = [reduction makeReduction];
        
        NSDate *finish = [NSDate date];
        NSTimeInterval executionTime = [finish timeIntervalSinceDate:start];
        NSLog(@"Matrix reduction execution time = %f ms", 1000 * executionTime);
        
        uint32_t nonNulCols = 0;
        for(uint32_t col = 0; col < reducedMatrix.n;col++) {
            nonNulCols += (reducedMatrix.colLengthsPtr[col] > 0);
        }
        
        NSLog(@"NonNullCols = %lu", nonNulCols);
        
        NSLog(@"computationTimeTotal = %f s", reduction.computationTimeTotal);
        NSLog(@"computeLowAndLeftColByLowGPUTime = %f s", reduction.computeLowAndLeftColByLowGPUTime);
        NSLog(@"computeNonZeroColsGPUTime = %f s", reduction.computeNonZeroColsGPUTime);
        NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f s", reduction.computeLeftColsAndLeftRightPairsGpuTime);
        NSLog(@"computeMatrixColLengthsGpuTime = %f s", reduction.computeMatrixColLengthsGpuTime);
        NSLog(@"executeLeftRightAdditionsGpuTime = %f s", reduction.executeLeftRightAdditionsGpuTime);
        NSLog(@"executeCopyLeftColumnsOnGpuTime = %f s", reduction.executeCopyLeftColumnsOnGpuTime);
        NSLog(@"computeMatrixColOffsetsGpuTime = %f s", reduction.computeMatrixColOffsetsGpuTime);
    }
    return 0;
}
