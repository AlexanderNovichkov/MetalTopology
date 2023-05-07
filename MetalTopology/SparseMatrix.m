#import "SparseMatrix.h"
#import <stdint.h>

@implementation SparseMatrix
{
}

- (instancetype) initWithDevice: (id<MTLDevice>) device FromFile: (NSString *) path
{
    self = [super init];
    if(self){
        NSString * fileContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSScanner *scanner=[NSScanner scannerWithString:fileContents];
        
        unsigned long long value;
        if(![scanner scanUnsignedLongLong:&value]) {
            NSLog(@"First number in file should set number of columns (simplices)");
            return nil;
        }
        _n = value;
        
        if(![scanner scanUnsignedLongLong:&value]) {
            NSLog(@"Second number in file should set number of non-zero elements in boundary matrix");
            return nil;
        }
        uint32_t nonZeros =  value;
        
        self.colOffsets = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
        self.colLengths = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
        self.rowIndices = [device newBufferWithLength:nonZeros * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
        
        
        uint32_t rowIndicesPos = 0;
        for(uint32_t col = 0; col < _n; col++){
            if(![scanner scanUnsignedLongLong:&value]) {
                NSLog(@"Error reading number of elements in column %u", col);
                return nil;
            }
            _colLengthsPtr[col] = value;
            _colOffsetsPtr[col] = rowIndicesPos;
            
            for(uint32_t i = 0; i < _colLengthsPtr[col];i++) {
                unsigned long long row;
                if(![scanner scanUnsignedLongLong:&value]) {
                    NSLog(@"Error reading element # %u for column # %u with length %llu", i, col, _colLengthsPtr[col]);
                    return nil;
                }
                _rowIndicesPtr[rowIndicesPos++] = value;
            }
        }
        
        if(rowIndicesPos != nonZeros) {
            NSLog(@"Actual number of non-zero elements=%u is not equal to number set in file=%u", rowIndicesPos, nonZeros);
            return nil;
        }
    }
    return self;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device N: (uint32_t) n {
    self = [super init];
    if(self) {
        _n = n;
        self.colOffsets = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
        self.colLengths = [device newBufferWithLength:_n * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
        self.rowIndices = [device newBufferWithLength: 1 * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    }
    return self;
}

- (void) writeToFile: (NSString *) path {
    NSString *str = [self description];
    [str writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (uint32_t) getNumberOfNonZeros {
    uint32_t count = 0;
    for(uint32_t col = 0; col < _n;col++) {
        count += _colLengthsPtr[col];
    }
    return count;
}

- (NSString *)description {
    NSMutableString *description = [[NSMutableString alloc]init];
    [description appendFormat:@"%u %u\n", _n, [self getNumberOfNonZeros]];

    for (int col = 0; col < _n;col++) {
        uint32_t offset = _colOffsetsPtr[col];
        uint32_t length = _colLengthsPtr[col];
        [description appendFormat:@"%u", length];
        for(uint32_t i = 0; i < length; i++) {
            uint32_t row = _rowIndicesPtr[offset + i];
            [description appendFormat:@" %u", row];
        }
        [description appendFormat:@"\n"];
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
