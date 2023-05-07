#import <XCTest/XCTest.h>

#import <Metal/Metal.h>

#import "SparseMatrixReduction.h"
#import "utils.h"

@interface SparseMatrixReductionTest : XCTestCase

@end

@implementation SparseMatrixReductionTest{
    id<MTLDevice> _mDevice;
}

- (void)setUp {
    _mDevice = MTLCreateSystemDefaultDevice();
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testOnMatrix1 {
    SparseMatrix *matrix = [self readMatrixFromFile:@"matrix_1.txt"];
    SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice:_mDevice Matrix:matrix];
    SparseMatrix *reducedMatrix = [reduction makeReduction];
    SparseMatrix *expectedReducedMatrix = [self readMatrixFromFile:@"matrix_1_reduced.txt"];
    XCTAssertEqualObjects([reducedMatrix description], [expectedReducedMatrix description]);
}

- (void)testOnMatrix2 {
    SparseMatrix *matrix = [self readMatrixFromFile:@"matrix_2.txt"];
    SparseMatrixReduction* reduction = [[SparseMatrixReduction alloc] initWithDevice:_mDevice Matrix:matrix];
    SparseMatrix *reducedMatrix = [reduction makeReduction];
    SparseMatrix *expectedReducedMatrix = [self readMatrixFromFile:@"matrix_2_reduced.txt"];
    XCTAssertEqualObjects([reducedMatrix description], [expectedReducedMatrix description]);
}

- (SparseMatrix*) readMatrixFromFile: (NSString*) filename {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString * path = [[bundle URLForResource:filename withExtension: nil] path];
    return [[SparseMatrix alloc] initWithDevice:_mDevice FromFile:path];
}

@end
