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

- (void)testSimple {
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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
