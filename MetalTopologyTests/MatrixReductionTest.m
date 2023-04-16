#import <XCTest/XCTest.h>

#import <Metal/Metal.h>

#import "MatrixReduction.h"
#import "utils.h"

@interface MatrixReductionTest : XCTestCase

@end

@implementation MatrixReductionTest{
    id<MTLDevice> _mDevice;
}

- (void)setUp {
    _mDevice = MTLCreateSystemDefaultDevice();
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testOnMatrix1 {
    bool matrixArray[3][2] = {
        {1, 0},
        {0, 0},
        {1, 1}
    };
    Matrix * matrix = makeMatrixFromArray(_mDevice, (bool *)matrixArray, 3, 2);
    
    MatrixReduction* reduction = [[MatrixReduction alloc] initWithDevice:_mDevice];
    [reduction makeReduction:matrix];
    
    bool expectedArray[3][2] = {
        {1, 1},
        {0, 0},
        {1, 0}
    };
    Matrix * expectedMatrix = makeMatrixFromArray(_mDevice, (bool *)expectedArray, 3, 2);
    XCTAssertEqualObjects([matrix description], [expectedMatrix description]);
}

- (void)testOnMatrix2 {
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
    Matrix * matrix = makeMatrixFromArray(_mDevice, (bool *)matrixArray, 9, 10);
    
    MatrixReduction* reduction = [[MatrixReduction alloc] initWithDevice:_mDevice];
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
    Matrix * expectedMatrix = makeMatrixFromArray(_mDevice, (bool *)expectedArray, 9, 10);
    
    XCTAssertEqualObjects([matrix description], [expectedMatrix description]);
}

@end
