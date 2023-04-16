#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import "Matrix.h"

void assertEqual(const Matrix* lhs, const Matrix * rhs);

Matrix * makeMatrixFromArray(id<MTLDevice> device, bool * array, uint rows, uint cols);
