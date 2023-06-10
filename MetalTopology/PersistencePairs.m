#import "PersistencePairs.h"
#import <Types.h>

@implementation PersistencePair
@end

@implementation PersistencePairs

- (instancetype)init {
  self = [super init];
  if (self) {
    _pairs = [[NSMutableArray alloc] init];
  }
  return self;
}

- (instancetype)initFromFile:(NSString *)path {
  self = [self init];
  if (self) {
    _pairs = [[NSMutableArray alloc] init];

    NSString *fileContents = [NSString stringWithContentsOfFile:path
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
    NSScanner *scanner = [NSScanner scannerWithString:fileContents];

    unsigned long long value;
    if (![scanner scanUnsignedLongLong:&value]) {
      NSLog(@"First number in file should set number of pairs");
      return nil;
    }
    index_t count = value;

    for (index_t i = 0; i < count; i++) {
      PersistencePair *pair = [[PersistencePair alloc] init];
      if (![scanner scanUnsignedLongLong:&value]) {
        NSLog(@"Error pair # %u", i + 1);
        return nil;
      }
      pair.birth = value;

      if (![scanner scanUnsignedLongLong:&value]) {
        NSLog(@"Error pair # %u", i + 1);
        return nil;
      }
      pair.death = value;

      [_pairs addObject:pair];
    }
  }
  return self;
}

- (void)sortPairsByBirth {
  [_pairs sortUsingComparator:^NSComparisonResult(PersistencePair *a, PersistencePair *b) {
    return a.birth > b.birth;
  }];
}

- (void)writeToFile:(NSString *)path {
  NSString *str = [self description];
  [str writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)description {
  NSMutableString *description = [[NSMutableString alloc] init];
  [description appendFormat:@"%lu\n", [_pairs count]];
  for (PersistencePair *pair in _pairs) {
    [description appendFormat:@"%u %u\n", pair.birth, pair.death];
  }
  return description;
}

@end
