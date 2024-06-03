//
//  ShaderUtils.metal
//  Talos3D
//
//  Created by Javier Salcedo on 20/4/23.
//
#ifndef __METAL_VERSION__
#error This file should only be included in shaders.
#else // __METAL_VERSION__

#ifndef ShaderUtils_h
#define ShaderUtils_h

#include <metal_stdlib>
using namespace metal;

/// Modulo calculated as in GLSL
template<typename T, typename U>
constexpr auto mod(T x, U y) -> T { return x - y * floor( x / y ); }


/// Calculates the inverse of the matrix using Gaussian elimination with partial pivoting.
/// - Return:
///		- Inverse of the input matrix if it's not singular.
///		- Otherwise returns the transpose which is *not correct* but at least is somewhat usable.
static auto inverse(float4x4 matrix) -> float4x4
{
    if (determinant(matrix) == 0)
    {
    	// It doesn't have an inverse, the transpose might be "close enough".
        return transpose(matrix);
    }

    float4x4 inverse;
    inverse.columns[0] = float4(1, 0, 0, 0);
    inverse.columns[1] = float4(0, 1, 0, 0);
    inverse.columns[2] = float4(0, 0, 1, 0);
    inverse.columns[3] = float4(0, 0, 0, 1);

    for (int i = 0; i < 4; ++i)
    {
        int pivot = i;
        for (int j = i + 1; j < 4; ++j)
        {
            if (fabs(matrix.columns[j][i]) > fabs(matrix.columns[pivot][i]))
            {
                pivot = j;
            }
        }
        if (pivot != i)
        {
            auto tmp = matrix.columns[i];
            matrix.columns[i] = matrix.columns[pivot];
            matrix.columns[pivot] = tmp;

            tmp = inverse.columns[i];
            inverse.columns[i] = inverse.columns[pivot];
            inverse.columns[pivot] = tmp;
        }

        auto tmp = matrix.columns[i][i];
        for (int j = 0; j < 4; ++j)
        {
            matrix.columns[i][j] /= tmp;
            inverse.columns[i][j] /= tmp;
        }

        for (int j = 0; j < 4; ++j)
        {
            if (j == i) continue;

            tmp = matrix.columns[j][i];
            for (int k = 0; k < 4; ++k)
            {
                matrix.columns[j][k] -= matrix.columns[i][k] * tmp;
                inverse.columns[j][k] -= inverse.columns[i][k] * tmp;
            }
        }
    }
    return inverse;
}

/// Fast matrix inversion, assuming it represents a linear transform (Rotation & Translation).
/// A linear transform can be decomposed into a rotation and a translation, and those matrices are
/// simple to invert.
/// - A rotation matrix is always orthonormal, so it can be inverted by simply transposing it.
/// - A translation matrix can be inverted just by negating the xyz of the last column.
///
/// - Parameters:
///     - M: Transform matrix to invert. Must be a linear transform.
/// - Returns:
///     - A new matrix, inverse of the input
static auto invert_linear_transform(float4x4 M) -> float4x4
{
    // M = |R T|
    //     |0 1|

    // Invert the translation
    // inv_t = |I -T|
    //         |0  1|
    auto inv_T = float4x4(1);
    inv_T.columns[3].xyz = -M.columns[3].xyz;

    // Invert the rotation.
    // inv_R = |R^t 0|
    //         | 0  1|
    auto inv_R = transpose(M);
    for (auto i=0u; i<3u; ++i)
    {
        inv_R.columns[i][3] = 0;
    }

    // NOTE: inv(T * R) = inv(R) * inv(T)
    return inv_R * inv_T;
}
#endif // ShaderUtils_h
#endif // __METAL_VERSION__
