#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "Matrix.h"

NS_ASSUME_NONNULL_BEGIN

@interface MatrixReduction : NSObject
- (instancetype) initWithDevice: (id<MTLDevice>) device;
- (void) makeReduction: (Matrix*) matrix;
@end

NS_ASSUME_NONNULL_END
