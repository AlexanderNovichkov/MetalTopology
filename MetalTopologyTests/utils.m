#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "utils.h"

void assertEqual(const Matrix* lhs, const Matrix * rhs) {
    XCTAssertEqual(lhs.rows, rhs.rows);
    XCTAssertEqual(lhs.cols, rhs.cols);
    for(uint row = 0; row < lhs.rows;row++) {
        for(uint col = 0; col < rhs.cols;col++) {
            XCTAssertEqual([lhs getRow:row Col:col], [rhs getRow:row Col:col]);
        }
    }
}

Matrix * makeMatrixFromArray(id<MTLDevice> device, bool* array, uint rows, uint cols){
    Matrix * matrix = [[Matrix alloc] initWithDevice:device Rows:rows Cols:cols];
    [matrix fillFromArray:array];
    return matrix;
}
