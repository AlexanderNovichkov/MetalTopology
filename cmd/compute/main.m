#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "SparseMatrixReduction.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * path = @"/Users/alex/Desktop/Education/4-cource/diploma/MetalTopologyBenchmark/datasets/klein_bottle_400/boundary_matrix.txt";

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();

        SparseMatrix *matrix = [[SparseMatrix alloc] initWithDevice:device FromFile:path];
        
        SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice: device Matrix:matrix];
        SparseMatrix *reducedMatrix = [reduction makeReduction];
        
        
        NSLog(@"%@", [reducedMatrix description]);
    }
    return 0;
}
