#import "SparseMatrix.h"
#import <stdint.h>

@implementation SparseMatrix
{
    int _kek;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device FromFile: (NSString *) path
{
    self = [super init];
    if(self){
        NSString * fileContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        int elements_in_matrix = 0;
        int col = 0;
        for (NSString *line in [fileContents componentsSeparatedByString:@"\n"]) {
            if([line length] > 0) {
                NSArray *stringNumbers = [line componentsSeparatedByString:@" "];
                for (NSString *stringNumber in stringNumbers) {
                    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                    NSNumber *number = [formatter numberFromString:stringNumber];
                    if (number) {
                        elements_in_matrix++;
                    }
                }
            }
            col++;
        }
        
        _n = col;
        self.colOffsets = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        self.colLengths = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        self.rowIndices = [device newBufferWithLength:elements_in_matrix * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        
        
        col = 0;
        int row_indices_pos = 0;
        for (NSString *line in [fileContents componentsSeparatedByString:@"\n"]) {
            _colOffsetsPtr[col] = row_indices_pos;
            if([line length] > 0) {
                NSArray *stringNumbers = [line componentsSeparatedByString:@" "];
                _colLengthsPtr[col] = 0;
                for (NSString *stringNumber in stringNumbers) {
                    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                    NSNumber *number = [formatter numberFromString:stringNumber];
                    if (number) {
                        _rowIndicesPtr[row_indices_pos] = [number unsignedIntValue];
                        row_indices_pos++;
                        _colLengthsPtr[col]++;
                    }
                }
            }
            col++;
        }
    }
    return self;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device N: (uint32_t) n {
    self = [super init];
    if(self) {
        _n = n;
        self.colOffsets = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        self.colLengths = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeShared];
        self.rowIndices = [device newBufferWithLength: 1 * sizeof(uint32_t) options:MTLResourceStorageModeShared];
    }
    return self;
}

- (void) writeToFile: (NSString *) path {
    NSString *str = [self description];
    [str writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


- (NSString *)description {
    NSMutableString *description = [[NSMutableString alloc]init];
//    [description appendFormat:@"%u\n", _n];

    for (int col = 0; col < _n;col++) {
        uint32_t offset = _colOffsetsPtr[col];
        uint32_t length = _colLengthsPtr[col];
        for(uint32_t i = 0; i < length; i++) {
            uint32_t row = _rowIndicesPtr[offset + i];
            [description appendFormat:@"%u", row];
            if(i + 1 != length) {
                [description appendFormat:@" "];
            }
        }
        if(col + 1 != _n) {
            [description appendString:@"\n"];
        }
    }
    return description;
}

- (void)setColOffsets:(id<MTLBuffer>) newColumnOffsets {
    _colOffsets = newColumnOffsets;
    _colOffsetsPtr = _colOffsets.contents;
}

- (void)setColLengths:(id<MTLBuffer>) newColumnLengths {
    _colLengths = newColumnLengths;
    _colLengthsPtr = _colLengths.contents;
}

- (void)setRowIndices:(id<MTLBuffer>)newRowIndices{
    _rowIndices = newRowIndices;
    _rowIndicesPtr = _rowIndices.contents;
}

@end
