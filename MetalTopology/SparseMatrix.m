#import "SparseMatrix.h"
#import <stdint.h>

#import "SparseMatrixBuilder.h"

@implementation SparseMatrix {
}

+ (instancetype)readWithDevice:(id<MTLDevice>)device FromMatrixFile:(NSString *)path {
  NSString *fileContents = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
  NSScanner *scanner = [NSScanner scannerWithString:fileContents];

  unsigned long long columns;
  if (![scanner scanUnsignedLongLong:&columns]) {
    NSLog(@"First number in file should set number of columns (simplices)");
    return nil;
  }

  unsigned long long nonZeros;
  if (![scanner scanUnsignedLongLong:&nonZeros]) {
    NSLog(@"Second number in file should set number of non-zero elements in boundary matrix");
    return nil;
  }

  SparseMatrixBuilder *builder =
      [[SparseMatrixBuilder alloc] initWithInitialColumnsCapacity:columns
                                   InitialNonZeroElementsCapacity:nonZeros];

  for (index_t col = 0; col < columns; col++) {
    [builder addColumn];
    unsigned long long colSize;
    if (![scanner scanUnsignedLongLong:&colSize]) {
      NSLog(@"Error reading number of elements in column %u", col);
      return nil;
    }

    for (index_t i = 0; i < colSize; i++) {
      unsigned long long row;
      if (![scanner scanUnsignedLongLong:&row]) {
        NSLog(@"Error reading nonZero row # %u for column # %u with length %llu", i, col, row);
        return nil;
      }
      [builder addNonZeroRowForLastColumn:row];
    }
  }

  if ([builder getNonZeroElementsCount] != nonZeros) {
    NSLog(@"Actual number of non-zero elements=%u is not equal to number set in file=%u",
          [builder getNonZeroElementsCount],
          nonZeros);
    return nil;
  }

  return [builder buildWithDevice:device];
}

+ (instancetype)readWithDevice:(id<MTLDevice>)device FromSimpliciesFile:(NSString *)path {
  NSString *fileContents = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
  NSScanner *scanner = [NSScanner scannerWithString:fileContents];

  unsigned long long simpliciesCount;
  if (![scanner scanUnsignedLongLong:&simpliciesCount]) {
    NSLog(@"First number in file should set number of simplices");
    return nil;
  }

  SparseMatrixBuilder *builder =
      [[SparseMatrixBuilder alloc] initWithInitialColumnsCapacity:simpliciesCount
                                   InitialNonZeroElementsCapacity:0];

  NSMutableDictionary *simplexToId = [NSMutableDictionary dictionary];
  for (index_t simplexId = 0; simplexId < simpliciesCount; simplexId++) {
    [builder addColumn];

    unsigned long long vertexCount;
    if (![scanner scanUnsignedLongLong:&vertexCount]) {
      NSLog(@"Error reading vertex count of simplex %u", simplexId);
      return nil;
    }
    NSMutableArray *simplex = [NSMutableArray arrayWithCapacity:vertexCount];
    for (index_t vertexId = 0; vertexId < vertexCount; vertexId++) {
      unsigned long long vertex;
      if (![scanner scanUnsignedLongLong:&vertex]) {
        NSLog(@"Error reading vertex # %u of simplex %u", vertexId, simplexId);
        return nil;
      }
      [simplex addObject:[NSNumber numberWithLongLong:vertex]];
    }
    [simplexToId setObject:[NSNumber numberWithLongLong:simplexId] forKey:simplex];

    if (vertexCount == 1) {
      continue;
    }

    NSMutableArray *boundary = [NSMutableArray arrayWithCapacity:vertexCount];
    for (index_t vertexId = 0; vertexId < vertexCount; vertexId++) {
      NSNumber *vertex = [simplex objectAtIndex:vertexId];
      [simplex removeObjectAtIndex:vertexId];

      NSNumber *simplexId = [simplexToId objectForKey:simplex];
      if (simplexId == nil) {
        1;
      }
      [boundary addObject:simplexId];

      [simplex insertObject:vertex atIndex:vertexId];
    }

    [boundary sortUsingSelector:@selector(compare:)];
    for (NSNumber *boundarySimplexId in boundary) {
      [builder addNonZeroRowForLastColumn:[boundarySimplexId unsignedLongLongValue]];
    }
  }

  return [builder buildWithDevice:device];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                    ColOffsets:(const NSMutableData *)colOffsets
                    ColLengths:(const NSMutableData *)colLengths
                    RowIndices:(const NSMutableData *)rowIndices {
  self = [super init];
  if (self) {
    _n = [colOffsets length] / sizeof(index_t);
    self.colOffsets = [device newBufferWithBytes:[colOffsets mutableBytes]
                                          length:[colOffsets length]
                                         options:MTLResourceStorageModeShared];
    self.colLengths = [device newBufferWithBytes:[colLengths mutableBytes]
                                          length:[colLengths length]
                                         options:MTLResourceStorageModeShared];
    self.rowIndices = [device newBufferWithBytes:[rowIndices mutableBytes]
                                          length:[rowIndices length]
                                         options:MTLResourceStorageModeShared];
  }
  return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device N:(index_t)n nonZeros:(index_t)nonZeros {
  self = [super init];
  if (self) {
    _n = n;
    self.colOffsets = [device newBufferWithLength:_n * sizeof(index_t)
                                          options:MTLResourceStorageModeShared];
    self.colLengths = [device newBufferWithLength:_n * sizeof(index_t)
                                          options:MTLResourceStorageModeShared];
    self.rowIndices = [device newBufferWithLength:nonZeros * sizeof(index_t)
                                          options:MTLResourceStorageModeShared];
  }
  return self;
}

- (void)writeToMatrixFile:(NSString *)path {
  NSString *str = [self description];
  [str writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (index_t)getNumberOfNonZeros {
  index_t count = 0;
  for (index_t col = 0; col < _n; col++) {
    count += _colLengthsPtr[col];
  }
  return count;
}

- (NSString *)description {
  NSMutableString *description = [[NSMutableString alloc] init];
  [description appendFormat:@"%u %u\n", _n, [self getNumberOfNonZeros]];

  for (int col = 0; col < _n; col++) {
    index_t offset = _colOffsetsPtr[col];
    index_t length = _colLengthsPtr[col];
    [description appendFormat:@"%u", length];
    for (index_t i = 0; i < length; i++) {
      index_t row = _rowIndicesPtr[offset + i];
      [description appendFormat:@" %u", row];
    }
    [description appendFormat:@"\n"];
  }
  return description;
}

- (void)setColOffsets:(id<MTLBuffer>)newColumnOffsets {
  _colOffsets = newColumnOffsets;
  _colOffsetsPtr = _colOffsets.contents;
}

- (void)setColLengths:(id<MTLBuffer>)newColumnLengths {
  _colLengths = newColumnLengths;
  _colLengthsPtr = _colLengths.contents;
}

- (void)setRowIndices:(id<MTLBuffer>)newRowIndices {
  _rowIndices = newRowIndices;
  _rowIndicesPtr = _rowIndices.contents;
}

@end
