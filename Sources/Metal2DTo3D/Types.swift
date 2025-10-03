//
//  Types.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/2/25.
//

import Foundation
import CoreGraphics

// Processing mode enum
enum ProcessingMode {
    case standard
    case fast
    case highQuality
}

// Main processing result
struct ProcessingResult {
    let depthMap: CGImage
    let meshData: Data
    let finalRender: CGImage
    let timing: ProcessingTiming
    let meshMetrics: MeshMetrics
}

// Timing information
struct ProcessingTiming {
    let segmentation: TimeInterval
    let depthEstimation: TimeInterval
    let meshGeneration: TimeInterval
    let total: TimeInterval
}

// Mesh statistics
struct MeshMetrics {
    let vertexCount: Int
    let triangleCount: Int
    let gpuMemoryUsage: Int
}
