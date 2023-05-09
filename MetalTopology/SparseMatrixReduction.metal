#include <metal_stdlib>
#include <metal_atomic>

#include "Types.h"


using namespace metal;

kernel void addMatrixColumns(device const index_t *matrixColOffsets,
                               device const index_t *matrixColLengths,
                               device const index_t *matrixRowIndices,
                               device const index_t *resultMatrixColOffsets,
                               device index_t *resultMatrixColLengths,
                               device index_t *resultMatrixRowIndices,
                               device const index_t * colToAdd,
                               uint2 gridPos [[thread_position_in_grid]])
{
    const index_t rightCol = gridPos[0];
    const index_t leftCol = colToAdd[rightCol];
    
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


kernel void computeLowAndLeftColByLow(device const index_t *matrixColOffsets,
                       device const index_t *matrixColLengths,
                       device const index_t *matrixRowIndices,
                       device index_t *lows,
                       device index_t *leftColByLow,
                       device index_t *nonZeroCols,
                       uint2 gridPos [[thread_position_in_grid]])
{
    const index_t col = nonZeroCols[gridPos[0]];
    const index_t length = matrixColLengths[col];
    if(length == 0) {
        lows[col] = MAX_INDEX;
        return;
    }
    
    const index_t offset = matrixColOffsets[col];
    const index_t low = matrixRowIndices[offset + length - 1];
    lows[col] = low;
    atomic_fetch_min_explicit((device atomic_uint*)(&leftColByLow[low]), col, memory_order_relaxed);
}

