#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "MatrixReduction.h"
#import "Matrix.h"


Matrix * makeMatrixFromArray(id<MTLDevice> device, bool* array, uint rows, uint cols){
    Matrix * matrix = [[Matrix alloc] initWithDevice:device Rows:rows Cols:cols];
    [matrix fillFromArray:array];
    return matrix;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        bool matrixArray[9][10] = {
            {0, 0, 1, 0, 0, 0, 0, 0, 0, 1},
            {0, 0, 1, 0, 0, 1, 1, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 1, 1, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 1, 0, 1},
            {0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        };
        Matrix * matrix = makeMatrixFromArray(device, (bool *)matrixArray, 9, 10);
        
        MatrixReduction* reduction = [[MatrixReduction alloc] initWithDevice:device];
        [reduction makeReduction:matrix];
        
        bool expectedArray[9][10] = {
            {0, 0, 1, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 1, 0, 0, 1, 1, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 1, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        };
        Matrix * expectedMatrix = makeMatrixFromArray(device, (bool *)expectedArray, 9, 10);
        
        
        
        NSLog([matrix description]);
        NSLog([expectedMatrix description]);
        assert([[matrix description] isEqualToString: [expectedMatrix description]]);
        
//
//
//        // Create the custom object used to encapsulate the Metal code.
//        // Initializes objects to communicate with the GPU.
//        MatrixReduction* matrix_reduction = [[MatrixReduction alloc] initWithDevice:device];
//
//
//        // Create buffers to hold data
//        [adder1 prepareData];
//
//
//        // Send a command to the GPU to perform the calculation.
//        [adder1 sendComputeCommand];
//
//        NSLog(@"Execution finished");
        
    }
    return 0;
}
