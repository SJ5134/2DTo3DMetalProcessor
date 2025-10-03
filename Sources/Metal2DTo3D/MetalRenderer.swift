//
//  MetalRenderer.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

import Foundation
import Metal
import MetalKit
import CoreGraphics

class MetalRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    // Compute pipelines
    var depthEstimationPipeline: MTLComputePipelineState?
    var meshGenerationPipeline: MTLComputePipelineState?
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "Metal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is not supported on this device"])
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw NSError(domain: "Metal", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create command queue"])
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create Metal library from source code
        self.library = try MetalRenderer.createMetalLibraryFromSource(device: device)
        
        // Create compute pipelines
        try createComputePipelines()
        
        print("   ✅ Metal renderer initialized with \(device.name)")
    }
    
    private static func createMetalLibraryFromSource(device: MTLDevice) throws -> MTLLibrary {
        let metalSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void depth_estimation_kernel(
            texture2d<float, access::read> inputTexture [[texture(0)]],
            texture2d<float, access::write> depthTexture [[texture(1)]],
            constant float& depthScale [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]])
        {
            uint width = inputTexture.get_width();
            uint height = inputTexture.get_height();
            
            if (gid.x >= width || gid.y >= height) {
                return;
            }
            
            float4 center = inputTexture.read(gid);
            
            // Get 8 neighboring pixels for better edge detection
            float3 neighbors[8];
            int idx = 0;
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    
                    int2 samplePos = int2(gid.x + dx, gid.y + dy);
                    samplePos = clamp(samplePos, int2(0, 0), int2(width-1, height-1));
                    
                    float4 sampleColor = inputTexture.read(uint2(samplePos));
                    neighbors[idx++] = sampleColor.rgb;
                }
            }
            
            // Convert to luminance
            float centerLum = 0.299 * center.r + 0.587 * center.g + 0.114 * center.b;
            
            // Calculate variance from neighbors (texture complexity)
            float lumVariance = 0.0;
            for (int i = 0; i < 8; i++) {
                float neighborLum = 0.299 * neighbors[i].r + 0.587 * neighbors[i].g + 0.114 * neighbors[i].b;
                lumVariance += abs(neighborLum - centerLum);
            }
            lumVariance /= 8.0;
            
            // Color-based depth (warmer colors = closer)
            float colorDepth = (center.r * 0.6 + center.g * 0.3 + center.b * 0.1);
            
            // Position-based depth (center = closer)
            float2 uv = float2(float(gid.x) / float(width), float(gid.y) / float(height));
            float2 centerVec = uv - float2(0.5, 0.5);
            float positionDepth = 1.0 - length(centerVec);
            
            // Combine techniques
            float edgeStrength = lumVariance * 3.0;
            float depth = (0.5 * (1.0 - saturate(edgeStrength * depthScale)) +
                          0.3 * colorDepth + 
                          0.2 * positionDepth);
            
            // Add subtle noise
            float noise = fract(sin(dot(float2(gid), float2(12.9898, 78.233))) * 43758.5453) * 0.05;
            depth = saturate(depth + noise);
            
            // Enhance contrast
            depth = pow(depth, 1.1);
            
            depthTexture.write(float4(depth, depth, depth, 1.0), gid);
        }
        
        kernel void mesh_generation_kernel(
            texture2d<float, access::read> depthTexture [[texture(0)]],
            texture2d<float, access::read> colorTexture [[texture(1)]],
            device float3* vertices [[buffer(0)]],
            device float2* texCoords [[buffer(1)]],
            device float3* colors [[buffer(2)]],
            device uint* indices [[buffer(3)]],
            constant float4x4& projectionMatrix [[buffer(4)]],
            uint tid [[thread_position_in_grid]])
        {
            uint width = depthTexture.get_width();
            uint height = depthTexture.get_height();
            uint totalVertices = width * height;
            
            if (tid >= totalVertices) {
                return;
            }
            
            // Calculate pixel coordinates
            uint x = tid % width;
            uint y = tid / width;
            
            // Read depth value
            float depthValue = depthTexture.read(uint2(x, y)).r;
            
            // Read color value for vertex coloring
            float4 colorValue = colorTexture.read(uint2(x, y));
            
            // Convert to 3D coordinates
            float3 position;
            position.x = (float(x) / float(width - 1)) * 2.0 - 1.0;
            position.y = (1.0 - (float(y) / float(height - 1))) * 2.0 - 1.0;
            position.z = depthValue * 2.0 - 1.0;
            
            // Store vertex data
            vertices[tid] = position;
            texCoords[tid] = float2(float(x) / float(width - 1), float(y) / float(height - 1));
            colors[tid] = colorValue.rgb;
            
            // Generate triangle indices for grid
            if (x < width - 1 && y < height - 1) {
                uint triangleBase = (y * (width - 1) + x) * 6;
                
                uint i0 = y * width + x;
                uint i1 = i0 + 1;
                uint i2 = i0 + width;
                uint i3 = i2 + 1;
                
                // First triangle
                indices[triangleBase] = i0;
                indices[triangleBase + 1] = i2;
                indices[triangleBase + 2] = i1;
                
                // Second triangle
                indices[triangleBase + 3] = i1;
                indices[triangleBase + 4] = i2;
                indices[triangleBase + 5] = i3;
            }
        }
        """
        
        do {
            return try device.makeLibrary(source: metalSource, options: nil)
        } catch {
            print("   ❌ Failed to compile Metal shaders: \(error)")
            throw NSError(domain: "Metal", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not compile Metal shaders: \(error)"])
        }
    }
    
    private func createComputePipelines() throws {
        print("   🔍 Loading Metal shader functions...")
        
        let functionNames = library.functionNames
        print("   📋 Available Metal functions: \(functionNames)")
        
        if let depthFunction = library.makeFunction(name: "depth_estimation_kernel") {
            depthEstimationPipeline = try device.makeComputePipelineState(function: depthFunction)
            print("   ✅ Loaded depth_estimation_kernel")
        } else {
            print("   ❌ FAILED to load depth_estimation_kernel")
            throw NSError(domain: "Metal", code: 3, userInfo: [NSLocalizedDescriptionKey: "Depth estimation kernel not found"])
        }
        
        if let meshFunction = library.makeFunction(name: "mesh_generation_kernel") {
            meshGenerationPipeline = try device.makeComputePipelineState(function: meshFunction)
            print("   ✅ Loaded mesh_generation_kernel")
        } else {
            print("   ❌ FAILED to load mesh_generation_kernel")
            throw NSError(domain: "Metal", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mesh generation kernel not found"])
        }
    }
    
    // MARK: - Public Methods
    
    func textureFromImage(_ image: CGImage) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.shared.rawValue
        ]
        
        return try textureLoader.newTexture(cgImage: image, options: options)
    }
    
    func createOutputTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw NSError(domain: "Metal", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create output texture"])
        }
        
        return texture
    }
    
    func createMaterialFile(at path: String) throws {
        let materialContent = """
        # Material file for textured mesh
        newmtl textured_material
        Ka 1.000 1.000 1.000
        Kd 1.000 1.000 1.000
        Ks 0.000 0.000 0.000
        d 1.0
        illum 2
        """
        
        try materialContent.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
    
    
    func estimateDepth(from image: CGImage) throws -> (depthTexture: MTLTexture, cgImage: CGImage) {
        let inputTexture = try textureFromImage(image)
        let outputTexture = try createOutputTexture(width: image.width, height: image.height)
        
        if let commandBuffer = commandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
           let pipeline = depthEstimationPipeline {
            
            commandEncoder.setComputePipelineState(pipeline)
            commandEncoder.setTexture(inputTexture, index: 0)
            commandEncoder.setTexture(outputTexture, index: 1)
            
            var depthScale: Float = 3.0
            commandEncoder.setBytes(&depthScale, length: MemoryLayout<Float>.size, index: 0)
            
            let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (image.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: (image.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                depth: 1
            )
            
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            print("   🎯 Used Metal compute shader for depth estimation")
        } else {
            simulateDepthOnCPU(inputTexture: inputTexture, outputTexture: outputTexture)
            print("   🔄 Used CPU fallback for depth estimation")
        }
        
        let depthCGImage = try convertTextureToCGImage(outputTexture)
        return (outputTexture, depthCGImage)
    }
    
    func generateMesh(from depthTexture: MTLTexture) throws -> Data {
        let width = depthTexture.width
        let height = depthTexture.height
        let vertexCount = width * height
        
        guard let vertexBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.size * vertexCount, options: .storageModeShared),
              let texCoordBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.size * vertexCount, options: .storageModeShared),
              let indexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * (width-1) * (height-1) * 6, options: .storageModeShared) else {
            throw NSError(domain: "Metal", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not create mesh buffers"])
        }
        
        if let commandBuffer = commandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
           let pipeline = meshGenerationPipeline {
            
            commandEncoder.setComputePipelineState(pipeline)
            commandEncoder.setTexture(depthTexture, index: 0)
            commandEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(texCoordBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(indexBuffer, offset: 0, index: 2)
            
            var projectionMatrix = matrix_identity_float4x4
            commandEncoder.setBytes(&projectionMatrix, length: MemoryLayout<matrix_float4x4>.size, index: 3)
            
            let threadsPerThreadgroup = MTLSize(width: 256, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (vertexCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: 1,
                depth: 1
            )
            
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            print("   🎯 Used Metal compute shader for mesh generation")
        } else {
            generateSimpleMeshCPU(vertexBuffer: vertexBuffer, texCoordBuffer: texCoordBuffer, indexBuffer: indexBuffer, width: width, height: height)
            print("   🔄 Used CPU fallback for mesh generation")
        }
        
        return convertToOBJFormat(vertexBuffer: vertexBuffer, texCoordBuffer: texCoordBuffer, indexBuffer: indexBuffer, vertexCount: vertexCount, width: width, height: height)
    }
    
    // Enhanced mesh generation with texture support
    func generateTexturedMesh(from depthTexture: MTLTexture, colorImage: CGImage) throws -> Data {
        let width = depthTexture.width
        let height = depthTexture.height
        let vertexCount = width * height
        
        // Create color texture from original image
        let colorTexture = try textureFromImage(colorImage)
        
        // Create buffers for mesh data
        guard let vertexBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.size * vertexCount, options: .storageModeShared),
              let texCoordBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.size * vertexCount, options: .storageModeShared),
              let colorBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.size * vertexCount, options: .storageModeShared),
              let indexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * (width-1) * (height-1) * 6, options: .storageModeShared) else {
            throw NSError(domain: "Metal", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not create mesh buffers"])
        }
        
        if let commandBuffer = commandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
           let pipeline = meshGenerationPipeline {
            
            commandEncoder.setComputePipelineState(pipeline)
            commandEncoder.setTexture(depthTexture, index: 0)
            commandEncoder.setTexture(colorTexture, index: 1)
            commandEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(texCoordBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(colorBuffer, offset: 0, index: 2)
            commandEncoder.setBuffer(indexBuffer, offset: 0, index: 3)
            
            var projectionMatrix = matrix_identity_float4x4
            commandEncoder.setBytes(&projectionMatrix, length: MemoryLayout<matrix_float4x4>.size, index: 4)
            
            let threadsPerThreadgroup = MTLSize(width: 256, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (vertexCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: 1,
                depth: 1
            )
            
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            print("   🎯 Used textured mesh generation shader")
        } else {
            generateSimpleMeshCPU(vertexBuffer: vertexBuffer, texCoordBuffer: texCoordBuffer, indexBuffer: indexBuffer, width: width, height: height)
            print("   🔄 Used CPU fallback for mesh generation")
        }
        
        // Convert to textured OBJ format
        return convertToTexturedOBJFormat(
            vertexBuffer: vertexBuffer,
            texCoordBuffer: texCoordBuffer,
            colorBuffer: colorBuffer,
            indexBuffer: indexBuffer,
            vertexCount: vertexCount,
            width: width,
            height: height
        )
    }

    // Enhanced OBJ export with materials
    private func convertToTexturedOBJFormat(
        vertexBuffer: MTLBuffer,
        texCoordBuffer: MTLBuffer,
        colorBuffer: MTLBuffer,
        indexBuffer: MTLBuffer,
        vertexCount: Int,
        width: Int,
        height: Int
    ) -> Data {
        var objString = "# Textured 3D Mesh generated by Metal2DTo3D\n"
        objString += "# Vertices: \(vertexCount)\n"
        objString += "# Resolution: \(width)x\(height)\n"
        objString += "mtllib textured_mesh.mtl\n\n"
        
        // Add vertices
        let vertices = vertexBuffer.contents().bindMemory(to: SIMD3<Float>.self, capacity: vertexCount)
        for i in 0..<vertexCount {
            let v = vertices[i]
            objString += "v \(v.x) \(v.y) \(v.z)\n"
        }
        
        objString += "\n"
        
        // Add texture coordinates
        let texCoords = texCoordBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: vertexCount)
        for i in 0..<vertexCount {
            let vt = texCoords[i]
            objString += "vt \(vt.x) \(1.0 - vt.y)\n"
        }
        
        objString += "\n"
        
        // Add vertex colors (as additional data)
        let colors = colorBuffer.contents().bindMemory(to: SIMD3<Float>.self, capacity: vertexCount)
        for i in 0..<vertexCount {
            let vc = colors[i]
            objString += "vc \(vc.x) \(vc.y) \(vc.z)\n"
        }
        
        objString += "\n"
        objString += "usemtl textured_material\n"
        
        // Add faces
        let triangleCount = (width - 1) * (height - 1) * 2
        let indices = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: triangleCount * 3)
        
        for i in 0..<triangleCount {
            let i1 = indices[i * 3] + 1
            let i2 = indices[i * 3 + 1] + 1
            let i3 = indices[i * 3 + 2] + 1
            
            objString += "f \(i1)/\(i1) \(i2)/\(i2) \(i3)/\(i3)\n"
        }
        
        return Data(objString.utf8)
    }
    
    // MARK: - CPU Fallback Implementations
    
    private func simulateDepthOnCPU(inputTexture: MTLTexture, outputTexture: MTLTexture) {
        let width = inputTexture.width
        let height = inputTexture.height
        
        var inputData = [UInt8](repeating: 0, count: width * height * 4)
        inputTexture.getBytes(&inputData, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        
        var outputData = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(inputData[index])
                let g = Float(inputData[index + 1])
                let b = Float(inputData[index + 2])
                
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                let depthValue = UInt8((1.0 - luminance) * 255.0)
                
                outputData[index] = depthValue
                outputData[index + 1] = depthValue
                outputData[index + 2] = depthValue
                outputData[index + 3] = 255
            }
        }
        
        outputTexture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: outputData, bytesPerRow: width * 4)
    }
    
    private func generateSimpleMeshCPU(vertexBuffer: MTLBuffer, texCoordBuffer: MTLBuffer, indexBuffer: MTLBuffer, width: Int, height: Int) {
        let vertices = vertexBuffer.contents().bindMemory(to: SIMD3<Float>.self, capacity: width * height)
        let texCoords = texCoordBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: width * height)
        let indices = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: (width-1) * (height-1) * 6)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let xNorm = Float(x) / Float(width)
                let yNorm = Float(y) / Float(height)
                let z = 0.5 + 0.3 * sin(xNorm * 6.0 * .pi) * cos(yNorm * 6.0 * .pi)
                
                vertices[index] = SIMD3<Float>(xNorm * 2.0 - 1.0, yNorm * 2.0 - 1.0, z)
                texCoords[index] = SIMD2<Float>(xNorm, yNorm)
            }
        }
        
        var indexCounter = 0
        for y in 0..<height-1 {
            for x in 0..<width-1 {
                let i0 = UInt32(y * width + x)
                let i1 = UInt32(y * width + x + 1)
                let i2 = UInt32((y + 1) * width + x)
                let i3 = UInt32((y + 1) * width + x + 1)
                
                indices[indexCounter] = i0
                indices[indexCounter + 1] = i2
                indices[indexCounter + 2] = i1
                
                indices[indexCounter + 3] = i1
                indices[indexCounter + 4] = i2
                indices[indexCounter + 5] = i3
                
                indexCounter += 6
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func convertTextureToCGImage(_ texture: MTLTexture) throws -> CGImage {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        
        var data = [UInt8](repeating: 0, count: width * height * 4)
        
        texture.getBytes(&data, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
              let cgImage = context.makeImage() else {
            throw NSError(domain: "Metal", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not convert texture to image"])
        }
        
        return cgImage
    }
    
    private func convertToOBJFormat(vertexBuffer: MTLBuffer, texCoordBuffer: MTLBuffer, indexBuffer: MTLBuffer, vertexCount: Int, width: Int, height: Int) -> Data {
        var objString = "# 3D Mesh generated by Metal2DTo3D\n"
        objString += "# Vertices: \(vertexCount)\n"
        objString += "# Resolution: \(width)x\(height)\n\n"
        
        let vertices = vertexBuffer.contents().bindMemory(to: SIMD3<Float>.self, capacity: vertexCount)
        for i in 0..<vertexCount {
            let v = vertices[i]
            objString += "v \(v.x) \(v.y) \(v.z)\n"
        }
        
        objString += "\n"
        
        let texCoords = texCoordBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: vertexCount)
        for i in 0..<vertexCount {
            let vt = texCoords[i]
            objString += "vt \(vt.x) \(1.0 - vt.y)\n"
        }
        
        objString += "\n"
        
        let triangleCount = (width - 1) * (height - 1) * 2
        let indices = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: triangleCount * 3)
        
        for i in 0..<triangleCount {
            let i1 = indices[i * 3] + 1
            let i2 = indices[i * 3 + 1] + 1
            let i3 = indices[i * 3 + 2] + 1
            
            objString += "f \(i1)/\(i1) \(i2)/\(i2) \(i3)/\(i3)\n"
        }
        
        return Data(objString.utf8)
    }
}
