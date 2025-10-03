//
//  ImageProcessor.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

import Foundation
import CoreGraphics
import Metal

class ImageProcessor {
    private let metalRenderer: MetalRenderer
    private let visionBridge: VisionMetalBridge
    
    init(metalRenderer: MetalRenderer) {
        self.metalRenderer = metalRenderer
        self.visionBridge = VisionMetalBridge(metalDevice: metalRenderer.device)
    }
    
    func processImage(_ image: CGImage, mode: ProcessingMode) throws -> ProcessingResult {
        print("⚡ Starting REAL Metal GPU Pipeline - Mode: \(mode)")
        
        let startTime = Date()
        
        // Step 1: Generate subject mask using Vision (but don't assign to unused variable)
        let segmentationStart = Date()
        print("🎭 Generating subject mask...")
        _ = try visionBridge.generateSubjectMask(from: image)  // FIXED: Use _ to indicate unused
        let segmentationTime = Date().timeIntervalSince(segmentationStart)
        print("✅ Subject segmentation completed")
        
        // Step 2: GPU Depth Estimation
        let depthStart = Date()
        print("🔍 Running GPU depth estimation...")
        let (depthTexture, depthMap) = try metalRenderer.estimateDepth(from: image)
        let depthTime = Date().timeIntervalSince(depthStart)
        print("✅ GPU depth estimation completed")
        
        // Step 3: GPU Mesh Generation
        let meshStart = Date()
        print("🕸️ Generating 3D mesh from depth map...")
        let meshData = try metalRenderer.generateMesh(from: depthTexture)
        let meshTime = Date().timeIntervalSince(meshStart)
        print("✅ GPU mesh generation completed")
        
        // Step 4: Final render (use original for now)
        _ = Date()  // FIXED: Remove unused renderTime variable
        let finalRender = image
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Calculate mesh metrics
        let meshMetrics = MeshMetrics(
            vertexCount: image.width * image.height,
            triangleCount: (image.width - 1) * (image.height - 1) * 2,
            gpuMemoryUsage: calculateGPUMemoryUsage(for: image)
        )
        
        return ProcessingResult(
            depthMap: depthMap,
            meshData: meshData,
            finalRender: finalRender,
            timing: ProcessingTiming(
                segmentation: segmentationTime,
                depthEstimation: depthTime,
                meshGeneration: meshTime,
                total: totalTime
            ),
            meshMetrics: meshMetrics
        )
    }
    
    func processImageFast(_ image: CGImage) throws -> ProcessingResult {
        print("⚡ FAST MODE: Simplified pipeline")
        
        let startTime = Date()
        
        // Fast mode: Skip segmentation, use basic depth estimation
        let depthStart = Date()
        let (depthTexture, depthMap) = try metalRenderer.estimateDepth(from: image)
        let depthTime = Date().timeIntervalSince(depthStart)
        
        // Generate simplified mesh
        let meshStart = Date()
        let meshData = try metalRenderer.generateMesh(from: depthTexture)
        let meshTime = Date().timeIntervalSince(meshStart)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        let meshMetrics = MeshMetrics(
            vertexCount: image.width * image.height,
            triangleCount: (image.width - 1) * (image.height - 1) * 2,
            gpuMemoryUsage: calculateGPUMemoryUsage(for: image) / 2 // Estimate for fast mode
        )
        
        return ProcessingResult(
            depthMap: depthMap,
            meshData: meshData,
            finalRender: image,
            timing: ProcessingTiming(
                segmentation: 0.0, // Skipped in fast mode
                depthEstimation: depthTime,
                meshGeneration: meshTime,
                total: totalTime
            ),
            meshMetrics: meshMetrics
        )
    }
    
    private func calculateGPUMemoryUsage(for image: CGImage) -> Int {
        // Estimate GPU memory usage in MB
        let width = image.width
        let height = image.height
        
        // Texture memory (input + output)
        let textureMemory = width * height * 4 * 2 // RGBA bytes for input and output
        
        // Vertex memory (positions + texture coordinates)
        let vertexMemory = width * height * (3 + 2) * 4 // x,y,z + u,v floats (4 bytes each)
        
        // Index memory (triangle indices)
        let indexMemory = (width - 1) * (height - 1) * 6 * 4 // indices (4 bytes each)
        
        // Mask texture memory
        let maskMemory = width * height // 1 byte per pixel for mask
        
        let totalBytes = textureMemory + vertexMemory + indexMemory + maskMemory
        return max(1, totalBytes / (1024 * 1024)) // Convert to MB, minimum 1MB
    }
    
    // Utility function to get processing statistics
    func getProcessingStats(_ result: ProcessingResult) -> [String: Any] {
        return [
            "total_time": result.timing.total,
            "segmentation_time": result.timing.segmentation,
            "depth_estimation_time": result.timing.depthEstimation,
            "mesh_generation_time": result.timing.meshGeneration,
            "vertex_count": result.meshMetrics.vertexCount,
            "triangle_count": result.meshMetrics.triangleCount,
            "gpu_memory_mb": result.meshMetrics.gpuMemoryUsage,
            "vertices_per_second": Double(result.meshMetrics.vertexCount) / result.timing.meshGeneration,
            "triangles_per_second": Double(result.meshMetrics.triangleCount) / result.timing.meshGeneration
        ]
    }
}
