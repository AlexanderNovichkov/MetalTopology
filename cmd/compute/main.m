#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "PhComputation.h"


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
        PhComputation* computation = [[PhComputation alloc] initWithDevice: device Matrix:matrix];
        [computation makeReduction];
        NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];
        
        NSLog(@"Computing PH done");
        
        NSLog(@"Matrix reduction execution time = %f ms", 1000 * executionTime);
        
        NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f s", computation.computeLeftColsAndLeftRightPairsGpuTime);
        NSLog(@"computeMatrixColLengthsGpuTime = %f s", computation.computeMatrixColLengthsGpuTime);
        NSLog(@"computeMatrixColOffsetsTime = %f s", computation.computeMatrixColOffsetsTime);
        NSLog(@"executeCopyLeftColumnsOnGpuTime = %f s", computation.executeCopyLeftColumnsOnGpuTime);
        NSLog(@"executeLeftRightAdditionsGpuTime = %f s", computation.executeLeftRightAdditionsGpuTime);
        NSLog(@"computeLowAndLeftColByLowGPUTime = %f s", computation.computeLowAndLeftColByLowGPUTime);
        NSLog(@"computeNonZeroColsGPUTime = %f s", computation.computeNonZeroColsGPUTime);
        NSLog(@"computationTimeTotal = %f s", computation.computationTimeTotal);
        
        
        NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f %%", computation.computeLeftColsAndLeftRightPairsGpuTime / computation.computationTimeTotal * 100.0);
        NSLog(@"computeMatrixColLengthsGpuTime = %f %%", computation.computeMatrixColLengthsGpuTime / computation.computationTimeTotal * 100.0);
        NSLog(@"computeMatrixColOffsetsTime = %f %%", computation.computeMatrixColOffsetsTime / computation.computationTimeTotal * 100.0);
        NSLog(@"executeCopyLeftColumnsOnGpuTime = %f %%", computation.executeCopyLeftColumnsOnGpuTime / computation.computationTimeTotal * 100.0);
        NSLog(@"executeLeftRightAdditionsGpuTime = %f %%", computation.executeLeftRightAdditionsGpuTime / computation.computationTimeTotal * 100.0);
        NSLog(@"computeLowAndLeftColByLowGPUTime = %f %%", computation.computeLowAndLeftColByLowGPUTime / computation.computationTimeTotal * 100.0);
        NSLog(@"computeNonZeroColsGPUTime = %f %%", computation.computeNonZeroColsGPUTime / computation.computationTimeTotal * 100.0);
        NSLog(@"computationTimeTotal = %f %%", computation.computationTimeTotal / computation.computationTimeTotal * 100.0);
        
        
        
        NSLog(@"Getting persistence pairs...");
        PersistencePairs *pairs = [computation getPersistentPairs];
        NSLog(@"Persistence pairs count = %lu", pairs.pairs.count);
        
        NSLog(@"Writing persistence pairs to file...");
        [pairs writeToFile: outputFile];
    }
    return 0;
}
