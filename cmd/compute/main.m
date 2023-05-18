#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "SparseMatrixReduction.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *inputFile, *outputFile;
        long gpuId = 0;
        
        
        if(argc < 3) {
            NSLog(@"Not enough arguments: argument 1 - path to input file, argument 2- path to output file, argument 3(optional) - GPU id (default 0)");
        }
        inputFile = [NSString stringWithUTF8String:argv[1]];
        outputFile = [NSString stringWithUTF8String:argv[2]];
        
        if(argc >=4) {
            gpuId = atol(argv[3]);
        }
        
        NSLog(@"inputFile=%@", inputFile);
        NSLog(@"outputFile=%@", outputFile);
        NSLog(@"gpuId=%lu", gpuId);
        
        id<MTLDevice> device = MTLCopyAllDevices()[gpuId];
        NSLog(@"Using GPU with name: %@", [device name]);

        NSLog(@"Reading input matrix...");
        SparseMatrix *matrix = [[SparseMatrix alloc] initWithDevice:device FromFile:inputFile];
        if(matrix == nil) {
            NSLog(@"Error reading matrix");
            return -1;
        }
    
        NSLog(@"Computing PH..");
        NSDate *start = [NSDate date];
        SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice: device Matrix:matrix];
        [reduction makeReduction];
        NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
        
        NSLog(@"Computing PH done");
        
        NSLog(@"Matrix reduction execution time = %f ms", 1000 * executionTime);
        
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
        
        
        
        NSLog(@"Getting persistence pairs...");
        PersistencePairs *pairs = [reduction getPersistentPairs];
        NSLog(@"Persistence pairs count = %lu", pairs.pairs.count);
        
        NSLog(@"Writing persistence pairs to file...");
        [pairs writeToFile: outputFile];
    }
    return 0;
}
