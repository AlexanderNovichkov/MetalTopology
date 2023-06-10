#import <Metal/Metal.h>
#import <XCTest/XCTest.h>

#import "SparseMatrixBuilder.h"

@interface SparseMatrixBuilderTest : XCTestCase

@end

@implementation SparseMatrixBuilderTest {
  id<MTLDevice> _mDevice;
}

- (void)setUp {
  _mDevice = MTLCreateSystemDefaultDevice();
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
}

- (void)testBuild {
  SparseMatrixBuilder *builder = [[SparseMatrixBuilder alloc] initWithInitialColumnsCapacity:4
                                                              InitialNonZeroElementsCapacity:0];
  [builder addColumn];

  [builder addColumn];

  [builder addColumn];
  [builder addNonZeroRowForLastColumn:1];
  [builder addNonZeroRowForLastColumn:2];

  [builder addColumn];
  [builder addNonZeroRowForLastColumn:3];

  SparseMatrix *matrix = [builder buildWithDevice:_mDevice];

  XCTAssertEqualObjects([matrix description], @"4 3\n0\n0\n2 1 2\n1 3\n");
}

@end
