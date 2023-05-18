#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "SparseMatrixReduction.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * path = @"/Users/alex/Desktop/Education/4-cource/diploma/MetalTopologyBenchmark/datasets/vr_boundary_matrices/human_gene_2_35.0_metal.txt";

        id<MTLDevice> device = MTLCopyAllDevices()[1];
        NSLog([device name]);

        SparseMatrix *matrix = [[SparseMatrix alloc] initWithDevice:device FromFile:path];
        
        NSDate *start = [NSDate date];
        
        SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice: device Matrix:matrix];
        SparseMatrix *reducedMatrix = [reduction makeReduction];
        
        NSDate *finish = [NSDate date];
        NSTimeInterval executionTime = [finish timeIntervalSinceDate:start];
        NSLog(@"Matrix reduction execution time = %f ms", 1000 * executionTime);
        
        uint32_t nonNulCols = 0;
        for(uint32_t col = 0; col < reducedMatrix.n;col++) {
            nonNulCols += (reducedMatrix.colLengthsPtr[col] > 0);
        }
        
        NSLog(@"NonNullCols = %lu", nonNulCols);
        
        NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f s", reduction.computeLeftColsAndLeftRightPairsGpuTime);
        NSLog(@"computeMatrixColLengthsGpuTime = %f s", reduction.computeMatrixColLengthsGpuTime);
        NSLog(@"computeMatrixColOffsetsTime = %f s", reduction.computeMatrixColOffsetsTime);
        NSLog(@"executeCopyLeftColumnsOnGpuTime = %f s", reduction.executeCopyLeftColumnsOnGpuTime);
        NSLog(@"executeLeftRightAdditionsGpuTime = %f s", reduction.executeLeftRightAdditionsGpuTime);
        NSLog(@"computeLowAndLeftColByLowGPUTime = %f s", reduction.computeLowAndLeftColByLowGPUTime);
        NSLog(@"computeNonZeroColsGPUTime = %f s", reduction.computeNonZeroColsGPUTime);
        NSLog(@"computationTimeTotal = %f s", reduction.computationTimeTotal);
        
        
        NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f %%", reduction.computeLeftColsAndLeftRightPairsGpuTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"computeMatrixColLengthsGpuTime = %f %%", reduction.computeMatrixColLengthsGpuTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"computeMatrixColOffsetsTime = %f %%", reduction.computeMatrixColOffsetsTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"executeCopyLeftColumnsOnGpuTime = %f %%", reduction.executeCopyLeftColumnsOnGpuTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"executeLeftRightAdditionsGpuTime = %f %%", reduction.executeLeftRightAdditionsGpuTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"computeLowAndLeftColByLowGPUTime = %f %%", reduction.computeLowAndLeftColByLowGPUTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"computeNonZeroColsGPUTime = %f %%", reduction.computeNonZeroColsGPUTime / reduction.computationTimeTotal * 100.0);
        NSLog(@"computationTimeTotal = %f %%", reduction.computationTimeTotal / reduction.computationTimeTotal * 100.0);
    }
    return 0;
}
