#include <metal_stdlib>
#include <metal_atomic>

#include "Types.h"


using namespace metal;

kernel void executeLeftRightAdditions(device const index_t *matrixColOffsets,
                               device const index_t *matrixColLengths,
                               device const index_t *matrixRowIndices,
                               device const index_t *resultMatrixColOffsets,
                               device index_t *resultMatrixColLengths,
                               device index_t *resultMatrixRowIndices,
                               device const LeftRightPair * leftRightPairs,
                               uint pairIdx [[thread_position_in_grid]])
{
    const index_t leftCol = leftRightPairs[pairIdx].leftCol;
    const index_t rightCol = leftRightPairs[pairIdx].rightCol;

    index_t leftColOffsetCur = (leftCol == MAX_INDEX) ? MAX_INDEX : matrixColOffsets[leftCol];
    const index_t leftColOffsetEnd = (leftCol == MAX_INDEX) ? MAX_INDEX : (leftColOffsetCur + matrixColLengths[leftCol]);

    index_t rightColOffsetCur = matrixColOffsets[rightCol];
    const index_t rightColOffsetEnd = rightColOffsetCur + matrixColLengths[rightCol];

    index_t resultColOffsetCur = resultMatrixColOffsets[rightCol];

    while (leftColOffsetCur < leftColOffsetEnd || rightColOffsetCur < rightColOffsetEnd) {
        index_t leftRow = (leftColOffsetCur < leftColOffsetEnd) ? matrixRowIndices[leftColOffsetCur] : MAX_INDEX;
        index_t rightRow = (rightColOffsetCur < rightColOffsetEnd) ? matrixRowIndices[rightColOffsetCur] : MAX_INDEX;

        if(leftRow < rightRow) {
            resultMatrixRowIndices[resultColOffsetCur] = leftRow;
            leftColOffsetCur++;
            resultColOffsetCur++;
        } else if(leftRow > rightRow) {
            resultMatrixRowIndices[resultColOffsetCur] = rightRow;
            rightColOffsetCur++;
            resultColOffsetCur++;
        } else {
            leftColOffsetCur++;
            rightColOffsetCur++;
        }
    }

    resultMatrixColLengths[rightCol] = resultColOffsetCur - resultMatrixColOffsets[rightCol];
}

kernel void copyLeftColumns(device const index_t *matrixColOffsets,
                               device const index_t *matrixColLengths,
                               device const index_t *matrixRowIndices,
                               device const index_t *resultMatrixColOffsets,
                               device index_t *resultMatrixRowIndices,
                               device const index_t * leftCols,
                               uint leftColsIdx [[thread_position_in_grid]])
{
    const index_t col = leftCols[leftColsIdx];
    
    const index_t length = matrixColLengths[col];
    index_t offset = matrixColOffsets[col];
    index_t resultMatrixOffset = resultMatrixColOffsets[col];
    
    for(index_t i = 0; i < length; i++) {
        resultMatrixRowIndices[resultMatrixOffset] = matrixRowIndices[offset];
        offset++;
        resultMatrixOffset++;
    }
}


kernel void computeLowAndLeftColByLow(device const index_t *matrixColOffsets,
                       device const index_t *matrixColLengths,
                       device const index_t *matrixRowIndices,
                       device index_t *lows,
                       device index_t *leftColByLow,
                       device index_t *nonZeroCols,
                       uint nonZeroColsIdx [[thread_position_in_grid]])
{
    const index_t col = nonZeroCols[nonZeroColsIdx];
    const index_t length = matrixColLengths[col];
    if(length == 0) {
        lows[col] = MAX_INDEX;
        return;
    }
    
    const index_t offset = matrixColOffsets[col];
    const index_t low = matrixRowIndices[offset + length - 1];
    lows[col] = low;
    atomic_fetch_min_explicit((device atomic_index_t*)(&leftColByLow[low]), col, memory_order_relaxed);
}


kernel void computeNonZeroCols(device const index_t *matrixColLengths,
                                      device index_t *nonZeroCols,
                                      device index_t *nonZeroColsResult,
                                      device atomic_index_t * nonZeroColsCount,
                                      uint idx [[thread_position_in_grid]])
{
    const index_t col = nonZeroCols[idx];
    if(matrixColLengths[col] != 0) {
        index_t pos = atomic_fetch_add_explicit(nonZeroColsCount, 1, memory_order_relaxed);
        nonZeroColsResult[pos] = col;
    }
}


kernel void computeLeftColsAndLeftRightPairs(device index_t *lows,
                                             device index_t *leftColByLow,
                                             device index_t *leftCols,
                                             device atomic_index_t *leftColsCount,
                                             device struct LeftRightPair* leftRightPairs,
                                             device atomic_index_t *leftRightPairsCount,
                                             device index_t *nonZeroCols,
                                             uint nonZeroColsIdx [[thread_position_in_grid]])
{
    const index_t col = nonZeroCols[nonZeroColsIdx];
    const index_t low = lows[col];
    const index_t left = leftColByLow[low];
    if(left == col) {
        index_t pos =  atomic_fetch_add_explicit(leftColsCount, 1, memory_order_relaxed);
        leftCols[pos] = col;
    } else {
        index_t pos =  atomic_fetch_add_explicit(leftRightPairsCount, 1, memory_order_relaxed);
        leftRightPairs[pos].leftCol = left;
        leftRightPairs[pos].rightCol = col;
    }
}


kernel void computeMatrixColLengths(device const index_t *matrixColLengths,
                                    device index_t *resultMatrixColLengths,
                                    device struct LeftRightPair *leftRightPairs,
                                    uint pairIdx [[thread_position_in_grid]])
{
    const LeftRightPair pair = leftRightPairs[pairIdx];
    resultMatrixColLengths[pair.rightCol] += matrixColLengths[pair.leftCol] - 2;
}
