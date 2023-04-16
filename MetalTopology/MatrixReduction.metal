#include <metal_stdlib>
using namespace metal;

kernel void add_arrays(device const uint* columnToAdd,
                       device const uint* columnAddTo,
                       device bool* matrix,
                       uint2 gridPos [[thread_position_in_grid]])
{
    uint task_idx = gridPos[0];
    uint col = gridPos[1];
    

    matrix[columnAddTo[task_idx] + col] =
        (matrix[columnAddTo[task_idx] + col] != matrix[columnToAdd[task_idx] + col]);
}
