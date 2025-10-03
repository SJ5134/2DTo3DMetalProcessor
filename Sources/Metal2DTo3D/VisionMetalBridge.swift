//
//  VisionMetalBridge.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

import Foundation
import Metal
import CoreGraphics
import Vision
import CoreVideo

class VisionMetalBridge {
    private let metalDevice: MTLDevice
    
    init(metalDevice: MTLDevice) {
        self.metalDevice = metalDevice
    }
    
    func generateSubjectMask(from image: CGImage) throws -> MTLTexture {
        print("   🎭 Generating subject mask...")
        
        let width = image.width
        let height = image.height
        
        // For now, skip Vision and use elliptical mask directly to avoid compatibility issues
        print("   🔄 Using elliptical mask (Vision framework skipped for compatibility)")
        return try generateEllipticalMask(width: width, height: height)
    }
    
    private func generateEllipticalMask(width: Int, height: Int) throws -> MTLTexture {
        // Create Metal texture for the mask
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared
        
        guard let texture = metalDevice.makeTexture(descriptor: textureDescriptor) else {
            throw MetalError.textureCreationFailed
        }
        
        // Generate elliptical mask data
        let maskData = generateEllipticalMaskData(width: width, height: height)
        
        // Copy mask data to texture
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: maskData,
            bytesPerRow: width
        )
        
        return texture
    }
    
    private func generateEllipticalMaskData(width: Int, height: Int) -> [UInt8] {
        var maskData = [UInt8](repeating: 0, count: width * height)
        
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0
        let radiusX = Double(width) / 3.0
        let radiusY = Double(height) / 3.0
        
        for y in 0..<height {
            for x in 0..<width {
                let dx = Double(x) - centerX
                let dy = Double(y) - centerY
                let normalizedX = dx / radiusX
                let normalizedY = dy / radiusY
                let distance = normalizedX * normalizedX + normalizedY * normalizedY
                
                if distance <= 1.0 {
                    // Inside ellipse - full subject
                    maskData[y * width + x] = 255
                } else if distance <= 1.3 {
                    // Soft edge - partial subject
                    let falloff = 1.0 - (distance - 1.0) / 0.3
                    let intensity = UInt8(falloff * 255.0)
                    maskData[y * width + x] = intensity
                }
                // Outside soft edge remains 0 (background)
            }
        }
        
        // Apply some smoothing to the mask
        return smoothMask(maskData, width: width, height: height)
    }
    
    private func smoothMask(_ mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        var smoothed = mask
        
        // Simple 3x3 box blur for smoothing
        for y in 1..<height-1 {
            for x in 1..<width-1 {
                var sum = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let index = (y + dy) * width + (x + dx)
                        sum += Int(mask[index])
                    }
                }
                smoothed[y * width + x] = UInt8(sum / 9)
            }
        }
        
        return smoothed
    }
}

// Error types
enum VisionError: Error {
    case segmentationFailed(String)
    case invalidInput(String)
}

enum MetalError: Error {
    case textureCreationFailed
    case bufferCreationFailed
}
