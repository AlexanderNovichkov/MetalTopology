#include <metal_stdlib>

using namespace metal;

kernel void addMatrixColumns(device const uint32_t *matrixColOffsets,
                               device const uint32_t *matrixColLengths,
                               device const uint32_t *matrixRowIndices,
                               device const uint32_t *resultMatrixColOffsets,
                               device uint32_t *resultMatrixColLengths,
                               device uint32_t *resultMatrixRowIndices,
                               device const uint32_t * colToAdd,
                               uint2 gridPos [[thread_position_in_grid]])
{
    const uint32_t rightCol = gridPos[0];
    const uint32_t leftCol = colToAdd[rightCol];
    
    uint32_t leftColOffsetCur = (leftCol == __UINT32_MAX__) ? __UINT32_MAX__ : matrixColOffsets[leftCol];
    const uint32_t leftColOffsetEnd = (leftCol == __UINT32_MAX__) ? __UINT32_MAX__ : (leftColOffsetCur + matrixColLengths[leftCol]);
    
    uint32_t rightColOffsetCur = matrixColOffsets[rightCol];
    const uint32_t rightColOffsetEnd = rightColOffsetCur + matrixColLengths[rightCol];
    
    uint32_t resultColOffsetCur = resultMatrixColOffsets[rightCol];
    
    while (leftColOffsetCur < leftColOffsetEnd || rightColOffsetCur < rightColOffsetEnd) {
        uint32_t leftRow = (leftColOffsetCur < leftColOffsetEnd) ? matrixRowIndices[leftColOffsetCur] : __UINT32_MAX__;
        uint32_t rightRow = (rightColOffsetCur < rightColOffsetEnd) ? matrixRowIndices[rightColOffsetCur] : __UINT32_MAX__;
        
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
