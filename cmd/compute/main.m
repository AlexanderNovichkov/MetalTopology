#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "PhComputation.h"

NSMutableDictionary *parseKeyValueArguments(int argc, const char *argv[]) {
  NSMutableDictionary *argToVal = [NSMutableDictionary dictionary];
  for (int i = 1; i < argc; i += 2) {
    NSString *arg = [NSString stringWithUTF8String:argv[i]];
    if (![arg hasPrefix:@"--"]) {
      NSLog(@"Incorrect argument %@", arg);
      exit(1);
    }
    if (i + 1 >= argc) {
      NSLog(@"Value for argument %@ not set", arg);
      exit(1);
    }
    NSString *val = [NSString stringWithUTF8String:argv[i + 1]];
    [argToVal setObject:val forKey:arg];
  }
  return argToVal;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    long gpuId = 0;
    NSString *inputType = @"matrix";
    NSString *inputFile, *outputFile;

    if (argc < 3) {
      NSLog(@"Not enough arguments: argument 1 - path to input file, argument 2- path to output "
            @"file");
    }
    inputFile = [NSString stringWithUTF8String:argv[argc - 2]];
    outputFile = [NSString stringWithUTF8String:argv[argc - 1]];

    NSDictionary *argToVal = parseKeyValueArguments(argc - 2, argv);
    if ([argToVal objectForKey:@"--gpuId"] != nil) {
      gpuId = [[argToVal objectForKey:@"--gpuId"] intValue];
    }
    if ([argToVal objectForKey:@"--inputType"] != nil) {
      inputType = [argToVal objectForKey:@"--inputType"];
    }

    NSLog(@"gpuId=%lu", gpuId);
    NSLog(@"inputType=%@", inputType);
    NSLog(@"inputFile=%@", inputFile);
    NSLog(@"outputFile=%@", outputFile);

    id<MTLDevice> device = MTLCopyAllDevices()[gpuId];
    NSLog(@"Using GPU with name: %@", [device name]);

    NSLog(@"Reading input matrix...");
    SparseMatrix *matrix;
    if ([inputType isEqualToString:@"matrix"]) {
      matrix = [SparseMatrix readWithDevice:device FromMatrixFile:inputFile];
    } else if ([inputType isEqualToString:@"matrix"]) {
      matrix = [SparseMatrix readWithDevice:device FromSimpliciesFile:inputFile];
    } else {
      NSLog(@"Incorrect inputType=%@", inputType);
      exit(1);
    }
    if (matrix == nil) {
      NSLog(@"Error reading matrix");
      return -1;
    }

    NSLog(@"Computing PH..");
    NSDate *start = [NSDate date];
    PhComputation *computation = [[PhComputation alloc] initWithDevice:device Matrix:matrix];
    [computation makeReduction];
    NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate:start];

    NSLog(@"Computing PH done");

    NSLog(@"Matrix reduction execution time = %f ms", 1000 * executionTime);

    NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f s",
          computation.computeLeftColsAndLeftRightPairsGpuTime);
    NSLog(@"computeMatrixColLengthsGpuTime = %f s", computation.computeMatrixColLengthsGpuTime);
    NSLog(@"computeMatrixColOffsetsTime = %f s", computation.computeMatrixColOffsetsTime);
    NSLog(@"executeCopyLeftColumnsOnGpuTime = %f s", computation.executeCopyLeftColumnsOnGpuTime);
    NSLog(@"executeLeftRightAdditionsGpuTime = %f s", computation.executeLeftRightAdditionsGpuTime);
    NSLog(@"computeLowAndLeftColByLowGPUTime = %f s", computation.computeLowAndLeftColByLowGPUTime);
    NSLog(@"computeNonZeroColsGPUTime = %f s", computation.computeNonZeroColsGPUTime);
    NSLog(@"computationTimeTotal = %f s", computation.computationTimeTotal);

    NSLog(@"computeLeftColsAndLeftRightPairsGpuTime = %f %%",
          computation.computeLeftColsAndLeftRightPairsGpuTime / computation.computationTimeTotal *
              100.0);
    NSLog(@"computeMatrixColLengthsGpuTime = %f %%",
          computation.computeMatrixColLengthsGpuTime / computation.computationTimeTotal * 100.0);
    NSLog(@"computeMatrixColOffsetsTime = %f %%",
          computation.computeMatrixColOffsetsTime / computation.computationTimeTotal * 100.0);
    NSLog(@"executeCopyLeftColumnsOnGpuTime = %f %%",
          computation.executeCopyLeftColumnsOnGpuTime / computation.computationTimeTotal * 100.0);
    NSLog(@"executeLeftRightAdditionsGpuTime = %f %%",
          computation.executeLeftRightAdditionsGpuTime / computation.computationTimeTotal * 100.0);
    NSLog(@"computeLowAndLeftColByLowGPUTime = %f %%",
          computation.computeLowAndLeftColByLowGPUTime / computation.computationTimeTotal * 100.0);
    NSLog(@"computeNonZeroColsGPUTime = %f %%",
          computation.computeNonZeroColsGPUTime / computation.computationTimeTotal * 100.0);
    NSLog(@"computationTimeTotal = %f %%",
          computation.computationTimeTotal / computation.computationTimeTotal * 100.0);

    NSLog(@"Getting persistence pairs...");
    PersistencePairs *pairs = [computation getPersistentPairs];
    NSLog(@"Persistence pairs count = %lu", pairs.pairs.count);

    NSLog(@"Writing persistence pairs to file...");
    [pairs writeToFile:outputFile];
  }
  return 0;
}
