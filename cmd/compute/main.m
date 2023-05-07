#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "SparseMatrixReduction.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * path = @"/Users/alex/Desktop/Education/4-cource/diploma/MetalTopologyBenchmark/datasets/klein_bottle_400/boundary_matrix.txt";

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSLog([device name]);

        SparseMatrix *matrix = [[SparseMatrix alloc] initWithDevice:device FromFile:path];
        
        SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice: device Matrix:matrix];
        SparseMatrix *reducedMatrix = [reduction makeReduction];
        
        uint32_t non_null_cols = 0;
        for(uint32_t col = 0; col < reducedMatrix.n;col++) {
            non_null_cols += (reducedMatrix.colLengthsPtr[col] > 0);
        }
        
//        NSLog(@"%@", [reducedMatrix description]);
        NSLog(@"non_null_cols = %lu", non_null_cols);
    }
    return 0;
}
