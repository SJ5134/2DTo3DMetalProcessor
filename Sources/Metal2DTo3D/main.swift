//
//  main.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

import Foundation
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

print("🚀 Metal 2D to 3D Conversion Pipeline")
print("=====================================")

// Check Metal availability
guard let device = MTLCreateSystemDefaultDevice() else {
    print("❌ Metal is not supported on this device")
    exit(1)
}

print("✅ Metal supported: \(device.name)")

do {
    // Initialize real Metal renderer
    let renderer = try MetalRenderer()
    
    // Try to load real image first, fall back to test image
    let image: CGImage
    if let realImage = loadRealImage() {
        image = realImage
        print("🖼️ REAL image loaded: \(image.width)x\(image.height)")
    } else {
        image = createTestImage(width: 512, height: 512)
        print("🖼️ TEST image created: \(image.width)x\(image.height)")
    }
    
    // Step 1: Real GPU Depth Estimation
    print("1. 🔍 Estimating depth with Metal compute shaders...")
    let (depthTexture, depthMap) = try renderer.estimateDepth(from: image)
    print("   ✅ Depth map generated")
    
    // Step 2: Real GPU Mesh Generation
    // Step 2: Real GPU Mesh Generation
    print("2. 🕸️ Generating 3D mesh from depth map...")
    let meshData = try renderer.generateTexturedMesh(from: depthTexture, colorImage: image)
    print("   ✅ 3D mesh generated")

    // Step 3: Save outputs
    print("3. 💾 Saving outputs...")
    try saveOutputs(depthMap: depthMap, meshData: meshData, originalImage: image)
    print("   ✅ All outputs saved")
    
    // Step 4: 3D Visualization
    print("4. 👁️ Generating 3D preview...")
    let meshPath = "./Outputs/Meshes/real_3d_mesh.obj"
    let originalImagePath = "./Outputs/Renders/original_image.png"
    let previewPath = "./Outputs/Renders/textured_3d_preview.usdz"
    MeshViewer.createTextured3DPreview(meshPath: meshPath, originalImagePath: originalImagePath, outputPath: previewPath)
    print("   ✅ 3D preview generated")

    // Create material file
    let materialPath = "./Outputs/Meshes/textured_mesh.mtl"
    try renderer.createMaterialFile(at: materialPath)
    print("   💾 Material file: \(materialPath)")
    
    print("🎉 REAL Metal GPU Pipeline Completed Successfully!")
    
} catch {
    print("❌ Error in Metal pipeline: \(error)")
    exit(1)
}

// MARK: - Image Loading Functions

func loadRealImage() -> CGImage? {
    let imagePath = "./Assets/TestImages/one.jpg"
    
    guard FileManager.default.fileExists(atPath: imagePath) else {
        print("   ⚠️ Real image not found at: \(imagePath)")
        return nil
    }
    
    let url = URL(fileURLWithPath: imagePath)
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        print("   ⚠️ Could not load image: \(imagePath)")
        return nil
    }
    
    print("   ✅ Successfully loaded real image: \(image.width)x\(image.height)")
    return image
}

func createTestImage(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fatalError("Could not create graphics context")
    }
    
    // Draw colorful gradient for better depth detection
    let colors = [
        CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),  // Red
        CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),  // Green
        CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0),  // Blue
        CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)   // Yellow
    ]
    
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 0.33, 0.66, 1.0])!
    
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: width, y: height),
        options: []
    )
    
    // Draw a prominent circle in center for 3D effect
    context.setFillColor(CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: width/2-80, y: height/2-80, width: 160, height: 160))
    
    guard let image = context.makeImage() else {
        fatalError("Could not create test image")
    }
    
    return image
}

// MARK: - Output Functions

func saveOutputs(depthMap: CGImage, meshData: Data, originalImage: CGImage) throws {
    // Save depth map as PNG
    let depthPath = "./Outputs/DepthMaps/real_depth_map.png"
    try saveImage(depthMap, to: depthPath)
    print("   💾 Depth map: \(depthPath)")
    
    // Save 3D mesh as OBJ
    let meshPath = "./Outputs/Meshes/real_3d_mesh.obj"
    try meshData.write(to: URL(fileURLWithPath: meshPath))
    print("   💾 3D mesh: \(meshPath) (\(meshData.count) bytes)")
    
    // Save original image for reference
    let originalPath = "./Outputs/Renders/original_image.png"
    try saveImage(originalImage, to: originalPath)
    print("   💾 Original: \(originalPath)")
    
    // Print mesh statistics
    let meshStats = String(data: meshData, encoding: .utf8) ?? ""
    let vertexCount = meshStats.components(separatedBy: "v ").count - 1
    let faceCount = meshStats.components(separatedBy: "f ").count - 1
    print("   📊 Mesh Statistics: \(vertexCount) vertices, \(faceCount) faces")
}

func saveImage(_ image: CGImage, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    
    // Create directory if needed
    let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    
    // Use the direct string identifier
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "ImageSave", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create image destination"])
    }
    
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}
