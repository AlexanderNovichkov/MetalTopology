#include <metal_atomic>
#include <metal_stdlib>

#include "Types.h"

using namespace metal;

kernel void makeInitialClearing(device const index_t *matrixColOffsets,
                                device index_t *matrixColLengths,
                                device const index_t *matrixRowIndices,
                                uint col [[thread_position_in_grid]]) {
  index_t length = matrixColLengths[col];
  if (length != 0) {
    index_t offset = matrixColOffsets[col];
    index_t low = matrixRowIndices[offset + length - 1];
    matrixColLengths[low] = 0;
  }
}

kernel void initNonZeroCols(device const index_t *matrixColLengths,
                            device index_t *nonZeroCols,
                            device atomic_index_t *nonZeroColsCount,
                            uint col [[thread_position_in_grid]]) {
  if (matrixColLengths[col] != 0) {
    index_t pos = atomic_fetch_add_explicit(nonZeroColsCount, 1, memory_order_relaxed);
    nonZeroCols[pos] = col;
  }
}

kernel void fillLeftColByLow(device index_t *leftColByLow, uint low [[thread_position_in_grid]]) {
  leftColByLow[low] = MAX_INDEX;
}

kernel void initLowAndLeftColByLow(device const index_t *matrixColOffsets,
                                   device const index_t *matrixColLengths,
                                   device const index_t *matrixRowIndices,
                                   device index_t *lows,
                                   device atomic_index_t *leftColByLow,
                                   device const index_t *nonZeroCols,
                                   uint nonZeroColsIdx [[thread_position_in_grid]]) {
  const index_t col = nonZeroCols[nonZeroColsIdx];
  const index_t length = matrixColLengths[col];
  if (length == 0) {
    lows[col] = MAX_INDEX;
    return;
  }

  const index_t offset = matrixColOffsets[col];
  const index_t l = matrixRowIndices[offset + length - 1];
  lows[col] = l;
  atomic_fetch_min_explicit(&leftColByLow[l], col, memory_order_relaxed);
}

kernel void computeMatrixOffsetsBlockSums(device const index_t *resultMatrixColLengths,
                                          device index_t *matrixOffsetsBlockSums,
                                          device const index_t *matrixSize,
                                          uint blockId [[thread_position_in_grid]]) {
  index_t colBegin = blockId * OFFSETS_BLOCK_SIZE;
  index_t colEnd = min(colBegin + OFFSETS_BLOCK_SIZE, *matrixSize);
  index_t sum = 0;
  for (index_t col = colBegin; col < colEnd; col++) {
    sum += resultMatrixColLengths[col];
  }
  matrixOffsetsBlockSums[blockId] = sum;
}

kernel void computeMatrixOffsets(device const index_t *resultMatrixColLengths,
                                 device const index_t *matrixOffsetsBlockPrefixSums,
                                 device const index_t *matrixSize,
                                 device index_t *resultMatrixColOffsets,
                                 uint blockId [[thread_position_in_grid]]) {
  index_t colBegin = blockId * OFFSETS_BLOCK_SIZE;
  index_t colEnd = min(colBegin + OFFSETS_BLOCK_SIZE, *matrixSize);
  index_t offset = (blockId == 0) ? 0 : matrixOffsetsBlockPrefixSums[blockId - 1];
  for (index_t col = colBegin; col < colEnd; col++) {
    resultMatrixColOffsets[col] = offset;
    offset += resultMatrixColLengths[col];
  }
}

kernel void executeLeftRightAdditions(device const index_t *matrixColOffsets,
                                      device const index_t *matrixColLengths,
                                      device const index_t *matrixRowIndices,
                                      device const index_t *resultMatrixColOffsets,
                                      device index_t *resultMatrixColLengths,
                                      device index_t *resultMatrixRowIndices,
                                      device const LeftRightPair *leftRightPairs,
                                      uint pairIdx [[thread_position_in_grid]]) {
  const uint32_t rightCol = leftRightPairs[pairIdx].rightCol;
  const uint32_t leftCol = leftRightPairs[pairIdx].leftCol;

  uint32_t leftColOffset = matrixColOffsets[leftCol];
  const uint32_t leftColOffsetEnd = (leftColOffset + matrixColLengths[leftCol]);

  const uint32_t rightColOffsetEnd = matrixColOffsets[rightCol] + matrixColLengths[rightCol];

  uint32_t resultColOffsetCur = resultMatrixColOffsets[rightCol];

  for (uint32_t rightColOffset = matrixColOffsets[rightCol]; rightColOffset < rightColOffsetEnd;
       rightColOffset++) {
    uint32_t rightRow = matrixRowIndices[rightColOffset];
    while (leftColOffset < leftColOffsetEnd && matrixRowIndices[leftColOffset] < rightRow) {
      resultMatrixRowIndices[resultColOffsetCur] = matrixRowIndices[leftColOffset];
      leftColOffset++;
      resultColOffsetCur++;
    }
    if (matrixRowIndices[leftColOffset] == rightRow) {
      leftColOffset++;
    } else {
      resultMatrixRowIndices[resultColOffsetCur] = rightRow;
      resultColOffsetCur++;
    }
  }

  resultMatrixColLengths[rightCol] = resultColOffsetCur - resultMatrixColOffsets[rightCol];
}

kernel void copyLeftColumns(device const index_t *matrixColOffsets,
                            device const index_t *matrixColLengths,
                            device const index_t *matrixRowIndices,
                            device const index_t *resultMatrixColOffsets,
                            device index_t *resultMatrixRowIndices,
                            device const index_t *leftCols,
                            uint leftColsIdx [[thread_position_in_grid]]) {
  const index_t col = leftCols[leftColsIdx];

  const index_t length = matrixColLengths[col];
  index_t offset = matrixColOffsets[col];
  index_t resultMatrixOffset = resultMatrixColOffsets[col];

  for (index_t i = 0; i < length; i++) {
    resultMatrixRowIndices[resultMatrixOffset] = matrixRowIndices[offset];
    offset++;
    resultMatrixOffset++;
  }
}

kernel void computeLowAndLeftColByLow(device const index_t *matrixColOffsets,
                                      device index_t *matrixColLengths,
                                      device const index_t *matrixRowIndices,
                                      device index_t *lows,
                                      device atomic_index_t *leftColByLow,
                                      device struct LeftRightPair *leftRightPairs,
                                      uint pairIdx [[thread_position_in_grid]]) {
  const index_t col = leftRightPairs[pairIdx].rightCol;
  const index_t length = matrixColLengths[col];
  if (length == 0) {
    lows[col] = MAX_INDEX;
    return;
  }

  const index_t offset = matrixColOffsets[col];
  const index_t l = matrixRowIndices[offset + length - 1];
  lows[col] = l;
  atomic_fetch_min_explicit(&leftColByLow[l], col, memory_order_relaxed);
}

kernel void computeNonZeroCols(device const index_t *matrixColLengths,
                               device const index_t *nonZeroCols,
                               device index_t *nonZeroColsResult,
                               device atomic_index_t *nonZeroColsCount,
                               uint idx [[thread_position_in_grid]]) {
  const index_t col = nonZeroCols[idx];
  if (matrixColLengths[col] != 0) {
    index_t pos = atomic_fetch_add_explicit(nonZeroColsCount, 1, memory_order_relaxed);
    nonZeroColsResult[pos] = col;
  }
}

kernel void computeLeftColsAndLeftRightPairs(device const index_t *lows,
                                             device const index_t *leftColByLow,
                                             device index_t *leftCols,
                                             device atomic_index_t *leftColsCount,
                                             device struct LeftRightPair *leftRightPairs,
                                             device atomic_index_t *leftRightPairsCount,
                                             device const index_t *nonZeroCols,
                                             uint nonZeroColsIdx [[thread_position_in_grid]]) {
  const index_t col = nonZeroCols[nonZeroColsIdx];
  const index_t low = lows[col];
  const index_t left = leftColByLow[low];
  if (left == col) {
    index_t pos = atomic_fetch_add_explicit(leftColsCount, 1, memory_order_relaxed);
    leftCols[pos] = col;
  } else {
    index_t pos = atomic_fetch_add_explicit(leftRightPairsCount, 1, memory_order_relaxed);
    leftRightPairs[pos].leftCol = left;
    leftRightPairs[pos].rightCol = col;
  }
}

kernel void computeMatrixColLengths(device const index_t *matrixColLengths,
                                    device index_t *resultMatrixColLengths,
                                    device const struct LeftRightPair *leftRightPairs,
                                    uint pairIdx [[thread_position_in_grid]]) {
  const LeftRightPair pair = leftRightPairs[pairIdx];
  resultMatrixColLengths[pair.rightCol] += matrixColLengths[pair.leftCol] - 2;
}
