//
//  ShaderTypes.h
//  Talos3D
//
//  Created by Javier Salcedo on 30/12/21.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, VertexAttributeIndices)
{
    POSITION = 0,
    COLOR,
    NORMAL,
    TEXCOORD,

    ATTRIBUTE_COUNT
};

typedef NS_ENUM(NSInteger, BufferIndices)
{
    VERTICES = 0,
    SCENE_MATRICES,
    OBJECT_MATRICES,
    LIGHTS,
    LIGHT_MATRIX,
    MATERIAL_PARAMS,
    CAMERA_POSITION,

    BUFFER_COUNT
};

typedef NS_ENUM(NSInteger, TextureIndices)
{
    ALBEDO = 0,
    SHADOW_MAP,
    SKYBOX,
    // For the deferred Lighting pass
    ALBEDO_AND_METALLIC,
    NORMAL_AND_ROUGHNESS,
    DEPTH,

    TEXTURE_COUNT
};

#endif /* ShaderTypes_h */

