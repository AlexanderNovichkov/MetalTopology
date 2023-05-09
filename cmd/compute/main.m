#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "SparseMatrixReduction.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * path = @"/Users/alex/Desktop/Education/4-cource/diploma/MetalTopologyBenchmark/datasets/vr_boundary_matrices/klein_2_100000.0_metal.txt";

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
        NSLog(@"colAdditionsGPUTime = %f s", reduction.colAdditionsGPUTime);
        
    }
    return 0;
}
