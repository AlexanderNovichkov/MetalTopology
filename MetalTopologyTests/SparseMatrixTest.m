#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

#import "SparseMatrix.h"

@interface SparseMatrixTest : XCTestCase

@end

@implementation SparseMatrixTest
{
    id<MTLDevice> _mDevice;
    SparseMatrix* _matrix;
}

- (void)setUp {
    _mDevice = MTLCreateSystemDefaultDevice();
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString * path = [[bundle URLForResource:@"matrix_1" withExtension:@"txt"] path];
    _matrix = [[SparseMatrix alloc] initWithDevice:_mDevice FromFile:path];

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}



- (void)testSize {
    XCTAssertEqual(_matrix.n, 4);
}


- (void) testDescription {
    XCTAssertEqualObjects([_matrix description], @"4\n\n0\n0 1\n1");
}

@end
