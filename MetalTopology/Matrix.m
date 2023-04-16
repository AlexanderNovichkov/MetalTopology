#import "Matrix.h"

@implementation Matrix
{
    bool* _dataPtr;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device Rows: (uint) rows Cols:(uint) cols
{
    self = [super init];
    if (self)
    {
        _rows = rows;
        _cols = cols;
        _dataBuffer = [device newBufferWithLength:rows*cols options:MTLResourceStorageModeShared];
        _dataPtr = _dataBuffer.contents;
    }
    return self;
}

- (NSInteger) getDataBufferOffsetForCol: (uint) col
{
    return col*_rows;
}


- (bool) getRow: (uint) row Col: (uint) col
{
    return _dataPtr[col * _rows + row];
}

- (void) setRow: (uint) row Col: (uint) col Val: (bool) val
{
    _dataPtr[col * _rows + row] = val;
}

- (void) fillFromArray: (bool*) array
{
    for(uint row = 0;row < _rows; row++) {
        for(uint col = 0; col < _cols; col++) {
            [self setRow:row Col:col Val: array[row * _cols + col]];
        }
    }
}

- (NSString *)description {
    NSMutableString *description = [[NSMutableString alloc]init];
    [description appendFormat:@"rows=%u, cols=%u\n", _rows, _cols];
    for(uint row = 0; row < _rows; row++) {
        for(uint col = 0; col < _cols; col++) {
            uint val = (uint)([self getRow:row Col: col]);
            [description appendFormat:@"%u ", val];
        }
        [description appendString:@"\n"];
    }
    return description;
}

@end
