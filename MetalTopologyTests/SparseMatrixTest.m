#import <Metal/Metal.h>
#import <XCTest/XCTest.h>

#import "SparseMatrix.h"

@interface SparseMatrixTest : XCTestCase

@end

@implementation SparseMatrixTest {
  id<MTLDevice> _mDevice;
  NSBundle *_bundle;
}

- (void)setUp {
  _mDevice = MTLCreateSystemDefaultDevice();
  _bundle = [NSBundle bundleForClass:[self class]];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
}

- (void)testReadFromSimpliciesFile {
  NSString *path = [[_bundle URLForResource:@"simplicies_0" withExtension:@"txt"] path];
  SparseMatrix *matrix = [SparseMatrix readWithDevice:_mDevice FromSimpliciesFile:path];

  XCTAssertEqualObjects([matrix description], @"7 9\n0\n0\n0\n2 0 1\n2 1 2\n2 0 2\n3 3 4 5\n");
  XCTAssertEqual(matrix.n, 7);
}

- (void)testReadFromMatrixFile {
  NSString *path = [[_bundle URLForResource:@"matrix_1" withExtension:@"txt"] path];
  SparseMatrix *matrix = [SparseMatrix readWithDevice:_mDevice FromMatrixFile:path];

  XCTAssertEqualObjects([matrix description], @"4 4\n0\n1 0\n2 0 1\n1 1\n");
  XCTAssertEqual(matrix.n, 4);
}

@end
