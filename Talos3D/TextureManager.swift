//
//  TextureManager.swift
//  Talos3D
//
//  Created by Javier Salcedo on 30/8/24.
//
// MARK: Imports
import Foundation
import MetalKit
import SimpleLogs


// MARK: Constants
let INVALID_HANDLE = TextureHandle.invalid()
let DUMMY_TEXTURE_HANDLE = TextureHandle(0)


// MARK: Types

// TODO: Use my static pool & handle system instead. This doesn't prevent stale handles!
struct TextureHandle
{
    public init(_ i: Int) { self.i = i }
    public static func invalid() -> Self { return Self(-1) }
    fileprivate let i: Int
}


class TextureManager
{
    // MARK: Public
    init(device: MTLDevice)
    {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)

        guard let dummy = Self.createMetalTexture(
            size: MTLSize(width: 1, height: 1, depth: 1),
            initialValue: 128,
            device: device)
        else
        {
            fatalError("Failed to create the dummy texture.")
        }
        var dummyTex = Texture(mtlTexture: dummy, label: "Dummy")
        dummyTex.setIndex(0, stage: .Fragment)
        self.textures.append( dummyTex )
    }


    /// Validates the provided `TextureHandle`.
    /// IMPORTANT: This *does not* check if the handle is stale.
    /// - Parameters:
    ///     - handle:
    /// - Returns:
    ///     - Wether the handle is valid or not
    public func validate( handle: TextureHandle ) -> Bool
    {
        handle.i >= 0 && handle.i < self.textures.count
    }


    /// Retrieves the texture corresponding to the provided handle, if any.
    /// - Parameters:
    ///     - handle:
    /// - Returns:
    ///     - The corresponding texture, if any. `nil` otherwise.
    public func getTexture(_ handle: TextureHandle) -> Texture?
    {
        if !self.validate(handle: handle)
        {
            return nil
        }
        return self.textures[handle.i]
    }


    /// Loads a texture from the bundle for use in shaders.
    /// NOTE: At the moment it only creates private, read-only textures.
    /// - Parameters:
    ///     - name:
    ///     - generateMipmaps:
    ///     - bindingPoint: Optional
    /// - Returns:
    ///     - A corresponding texture handle
    public func loadTexture(
        name: String,
        generateMipmaps: Bool,
        bindingPoint: BindingPoint? = nil )
    -> TextureHandle
    {
        // TODO: Async?

        // TODO: Make this configurable
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage:       NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue),
            MTKTextureLoader.Option.generateMipmaps:    NSNumber(value: generateMipmaps) ]

        do
        {
            let mtlTex = try self.textureLoader.newTexture(
                name: name,
                scaleFactor: 1.0,
                bundle: nil,
                options: textureLoaderOptions)

            var texture = Texture(mtlTexture: mtlTex, label: name)
            if let bp = bindingPoint
            {
                texture.setIndex(bp.index, stage: bp.stage)
            }
            self.textures.append( texture )

            return TextureHandle(self.textures.count - 1)
        }
        catch
        {
            ERROR("Couldn't load texture \(name)")
            return TextureHandle.invalid()
        }
    }


    // MARK: Private

    /// Creates a new Metal Texture with a given size and initial value
    /// - Parameters:
    ///     - size
    ///     - initialValue: [0,255] Will be set for all channels of all texels
    ///     - device: The device used to create the texture
    /// - Returns:
    ///     - MTLTexture: With RGBA8Unorm pixel format
    private static func createMetalTexture(
        size:           MTLSize,
        initialValue:   UInt8,
        device:         MTLDevice)
    -> MTLTexture?
    {
        let texDesc = MTLTextureDescriptor()
        texDesc.width  = size.width
        texDesc.height = size.height
        texDesc.depth  = size.depth

        guard let mtlTex = device.makeTexture(descriptor: texDesc) else
        {
            ERROR("Failed to create texture.")
            return nil
        }

        let dataSize = 4 * size.width * size.height * size.depth
        let data = Array(repeating: initialValue, count: dataSize)

        mtlTex.replace(region:      MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: size),
                       mipmapLevel: 0,
                       withBytes:   data,
                       bytesPerRow: dataSize)

        return mtlTex
    }

    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader

    private var textures: [Texture] = []
}
