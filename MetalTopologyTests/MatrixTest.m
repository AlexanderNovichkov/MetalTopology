#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

#import "Matrix.h"

@interface MatrixTest : XCTestCase

@end

@implementation MatrixTest
{
    id<MTLDevice> _mDevice;
    Matrix *_matrix23;
}

- (void)setUp {
    _mDevice = MTLCreateSystemDefaultDevice();
    _matrix23 = [[Matrix alloc] initWithDevice:_mDevice Rows:2 Cols:3];

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSize {
    XCTAssertEqual(_matrix23.rows, 2);
    XCTAssertEqual(_matrix23.cols, 3);
}

- (void)testSetGet {
    XCTAssertEqual([_matrix23 getRow:1 Col:2], 0);
    [_matrix23 setRow:1 Col:2 Val:1];
    XCTAssertEqual([_matrix23 getRow:1 Col:2], 1);
    XCTAssertEqual([_matrix23 getRow:1 Col:1], 0);
    XCTAssertEqual([_matrix23 getRow:1 Col:3], 0);
    [_matrix23 setRow:1 Col:2 Val:0];
    XCTAssertEqual([_matrix23 getRow:0 Col:0], 0);
}

- (void)testFill {
    bool array[2][3] = {
        {1, 0, 1},
        {0, 0, 1}
    };
    [_matrix23 fillFromArray: (bool*) array];
    
    XCTAssertEqual([_matrix23 getRow:0 Col:0], 1);
    XCTAssertEqual([_matrix23 getRow:0 Col:1], 0);
    XCTAssertEqual([_matrix23 getRow:0 Col:2], 1);
    XCTAssertEqual([_matrix23 getRow:1 Col:0], 0);
    XCTAssertEqual([_matrix23 getRow:1 Col:1], 0);
    XCTAssertEqual([_matrix23 getRow:1 Col:2], 1);
}

- (void) testGetDataBufferOffsetForCol {
    XCTAssertEqual([_matrix23 getDataBufferOffsetForCol:0], 0);
    XCTAssertEqual([_matrix23 getDataBufferOffsetForCol:1], 2);
    XCTAssertEqual([_matrix23 getDataBufferOffsetForCol:2], 4);
}

@end
