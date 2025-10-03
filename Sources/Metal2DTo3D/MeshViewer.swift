//
//  MeshViewer.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/2/25.
//

import Foundation
import SceneKit

class MeshViewer {
    static func createSimple3DPreview(meshPath: String, outputPath: String) {
        print("   👁️ Creating 3D preview...")
        
        // Create directories if they don't exist
        let outputURL = URL(fileURLWithPath: outputPath)
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        guard FileManager.default.fileExists(atPath: meshPath) else {
            print("   ⚠️ Mesh file not found: \(meshPath)")
            return
        }
        
        do {
            // Read the OBJ file
            let objContent = try String(contentsOfFile: meshPath)
            let lines = objContent.components(separatedBy: .newlines)
            
            // Parse vertices and faces from OBJ
            var vertices: [SCNVector3] = []
            var faces: [[Int]] = []
            
            for line in lines {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard !components.isEmpty else { continue }
                
                if components[0] == "v" && components.count >= 4 {
                    // Vertex position
                    let x = Float(components[1]) ?? 0
                    let y = Float(components[2]) ?? 0
                    let z = Float(components[3]) ?? 0
                    vertices.append(SCNVector3(x, y, z))
                }
                else if components[0] == "f" && components.count >= 4 {
                    // Face indices (OBJ uses 1-based indexing)
                    var faceIndices: [Int] = []
                    for i in 1...3 {
                        let faceComponent = components[i]
                        let vertexIndex = Int(faceComponent.components(separatedBy: "/")[0]) ?? 0
                        faceIndices.append(vertexIndex - 1) // Convert to 0-based
                    }
                    faces.append(faceIndices)
                }
            }
            
            print("   📊 Loaded \(vertices.count) vertices and \(faces.count) faces for 3D preview")
            
            // Create scene
            let scene = SCNScene()
            
            // Create camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 100.0
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
            scene.rootNode.addChildNode(cameraNode)
            
            // Create mesh geometry if we have faces
            if !faces.isEmpty && !vertices.isEmpty {
                // Convert faces to triangle indices
                var indices: [Int32] = []
                for face in faces {
                    for vertexIndex in face {
                        indices.append(Int32(vertexIndex))
                    }
                }
                
                // Create geometry sources
                let vertexSource = SCNGeometrySource(vertices: vertices)
                let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
                let element = SCNGeometryElement(
                    data: indexData,
                    primitiveType: .triangles,
                    primitiveCount: indices.count / 3,
                    bytesPerIndex: MemoryLayout<Int32>.size
                )
                
                let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
                
                // Create material
                let material = SCNMaterial()
                material.diffuse.contents = NSColor.blue
                material.specular.contents = NSColor.white
                material.shininess = 0.5
                material.isDoubleSided = true
                material.fillMode = .lines // Wireframe style
                geometry.materials = [material]
                
                let meshNode = SCNNode(geometry: geometry)
                scene.rootNode.addChildNode(meshNode)
                
                print("   🔷 Created 3D mesh with \(vertices.count) vertices and \(faces.count) faces")
            } else {
                print("   ⚠️ No faces found in OBJ, creating point cloud instead")
                // Fallback to point cloud if no faces
                createPointCloud(scene: scene, vertices: vertices)
            }
            
            // Add lighting
            addLighting(to: scene)
            
            // Save as USDZ file
            let url = URL(fileURLWithPath: outputPath)
            let success = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
            
            if success {
                print("   💾 3D preview saved: \(outputPath)")
                print("   👉 Double-click the file to view in 3D (macOS QuickLook)")
            } else {
                print("   ⚠️ Failed to save 3D preview")
                // Create a fallback text file
                createFallbackPreview(meshPath: meshPath, outputPath: outputPath)
            }
            
        } catch {
            print("   ⚠️ Could not create 3D preview: \(error)")
            createFallbackPreview(meshPath: meshPath, outputPath: outputPath)
        }
    }
    
    static func createTextured3DPreview(meshPath: String, originalImagePath: String, outputPath: String) {
        print("   🎨 Creating textured 3D preview...")
        
        // Create directories if they don't exist
        let outputURL = URL(fileURLWithPath: outputPath)
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        guard FileManager.default.fileExists(atPath: meshPath) else {
            print("   ⚠️ Mesh file not found: \(meshPath)")
            return
        }
        
        do {
            // Read the OBJ file
            let objContent = try String(contentsOfFile: meshPath)
            let lines = objContent.components(separatedBy: .newlines)
            
            // Parse vertices, texture coordinates, and faces
            var vertices: [SCNVector3] = []
            var texCoords: [SIMD2<Float>] = []
            var faces: [[Int]] = []
            
            for line in lines {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard !components.isEmpty else { continue }
                
                switch components[0] {
                case "v" where components.count >= 4:
                    // Vertex position
                    let x = Float(components[1]) ?? 0
                    let y = Float(components[2]) ?? 0
                    let z = Float(components[3]) ?? 0
                    vertices.append(SCNVector3(x, y, z))
                    
                case "vt" where components.count >= 3:
                    // Texture coordinate
                    let u = Float(components[1]) ?? 0
                    let v = Float(components[2]) ?? 0
                    texCoords.append(SIMD2<Float>(u, v))
                    
                case "f" where components.count >= 4:
                    // Face indices
                    var faceIndices: [Int] = []
                    for i in 1...3 {
                        let faceComponent = components[i]
                        let indices = faceComponent.components(separatedBy: "/")
                        let vertexIndex = Int(indices[0]) ?? 0
                        faceIndices.append(vertexIndex - 1) // Convert to 0-based
                    }
                    faces.append(faceIndices)
                default:
                    break
                }
            }
            
            print("   📊 Loaded \(vertices.count) vertices, \(texCoords.count) texture coords, \(faces.count) faces")
            
            // Create scene
            let scene = SCNScene()
            
            // Create camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 100.0
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
            scene.rootNode.addChildNode(cameraNode)
            
            // Create textured mesh if we have texture coordinates
            if !faces.isEmpty && !vertices.isEmpty && !texCoords.isEmpty {
                // Convert faces to triangle indices
                var indices: [Int32] = []
                for face in faces {
                    for vertexIndex in face {
                        indices.append(Int32(vertexIndex))
                    }
                }
                
                // Create geometry sources
                let vertexSource = SCNGeometrySource(vertices: vertices)
                
                // Create texture coordinate source
                let texCoordData = Data(bytes: texCoords, count: texCoords.count * MemoryLayout<SIMD2<Float>>.size)
                let texCoordSource = SCNGeometrySource(
                    data: texCoordData,
                    semantic: .texcoord,
                    vectorCount: texCoords.count,
                    usesFloatComponents: true,
                    componentsPerVector: 2,
                    bytesPerComponent: MemoryLayout<Float>.size,
                    dataOffset: 0,
                    dataStride: MemoryLayout<SIMD2<Float>>.size
                )
                
                // Create geometry element
                let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
                let element = SCNGeometryElement(
                    data: indexData,
                    primitiveType: .triangles,
                    primitiveCount: indices.count / 3,
                    bytesPerIndex: MemoryLayout<Int32>.size
                )
                
                let geometry = SCNGeometry(sources: [vertexSource, texCoordSource], elements: [element])
                
                // Load and apply texture if available
                if FileManager.default.fileExists(atPath: originalImagePath),
                   let textureImage = NSImage(contentsOfFile: originalImagePath) {
                    let material = SCNMaterial()
                    material.diffuse.contents = textureImage
                    material.isDoubleSided = true
                    geometry.materials = [material]
                    print("   🖼️ Applied texture from: \(originalImagePath)")
                } else {
                    let material = SCNMaterial()
                    material.diffuse.contents = NSColor.blue
                    material.isDoubleSided = true
                    geometry.materials = [material]
                    print("   🔷 Using default blue material")
                }
                
                let meshNode = SCNNode(geometry: geometry)
                scene.rootNode.addChildNode(meshNode)
                
                print("   🎨 Created textured 3D mesh")
            } else {
                print("   ⚠️ Insufficient data for textured mesh, creating basic mesh")
                createBasicMesh(scene: scene, vertices: vertices, faces: faces)
            }
            
            // Add lighting
            addLighting(to: scene)
            
            // Save as USDZ file
            let url = URL(fileURLWithPath: outputPath)
            let success = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
            
            if success {
                print("   💾 Textured 3D preview saved: \(outputPath)")
                print("   👉 Double-click to view in 3D with textures!")
            } else {
                print("   ⚠️ Failed to save textured 3D preview")
            }
            
        } catch {
            print("   ⚠️ Could not create textured 3D preview: \(error)")
        }
    }

    private static func createBasicMesh(scene: SCNScene, vertices: [SCNVector3], faces: [[Int]]) {
        guard !faces.isEmpty && !vertices.isEmpty else { return }
        
        var indices: [Int32] = []
        for face in faces {
            for vertexIndex in face {
                indices.append(Int32(vertexIndex))
            }
        }
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.green
        material.isDoubleSided = true
        material.fillMode = .lines
        geometry.materials = [material]
        
        let meshNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(meshNode)
    }
    
    
    private static func createPointCloud(scene: SCNScene, vertices: [SCNVector3]) {
        guard !vertices.isEmpty else { return }
        
        // Create sphere geometry for each point
        let sphereGeometry = SCNSphere(radius: 0.02)
        sphereGeometry.firstMaterial?.diffuse.contents = NSColor.red
        sphereGeometry.firstMaterial?.specular.contents = NSColor.white
        
        for vertex in vertices {
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.position = vertex
            scene.rootNode.addChildNode(sphereNode)
        }
        
        print("   🔴 Created point cloud with \(vertices.count) points")
    }
    
    private static func addLighting(to scene: SCNScene) {
        // Add ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.3, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Add directional light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = NSColor(white: 0.8, alpha: 1.0)
        directionalLight.castsShadow = true
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.position = SCNVector3(x: 5, y: 5, z: 5)
        directionalNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalNode)
        
        // Add omni light
        let omniLight = SCNLight()
        omniLight.type = .omni
        omniLight.color = NSColor(white: 0.6, alpha: 1.0)
        let omniNode = SCNNode()
        omniNode.light = omniLight
        omniNode.position = SCNVector3(x: -3, y: 3, z: 3)
        scene.rootNode.addChildNode(omniNode)
    }
    
    private static func createFallbackPreview(meshPath: String, outputPath: String) {
        // Create a simple text file with mesh info
        do {
            let objContent = try String(contentsOfFile: meshPath)
            let lines = objContent.components(separatedBy: .newlines)
            
            let vertexCount = lines.filter { $0.hasPrefix("v ") }.count
            let faceCount = lines.filter { $0.hasPrefix("f ") }.count
            
            let infoContent = """
            3D Mesh Information
            ==================
            File: \(meshPath)
            Vertices: \(vertexCount)
            Faces: \(faceCount)
            Generated: \(Date())
            
            To view this mesh:
            1. Open in Blender (free)
            2. Open in MeshLab (free) 
            3. Use online OBJ viewers
            
            Mesh Preview generated by Metal2DTo3D
            """
            
            let infoPath = outputPath.replacingOccurrences(of: ".usdz", with: "_INFO.txt")
            try infoContent.write(to: URL(fileURLWithPath: infoPath), atomically: true, encoding: .utf8)
            
            print("   📝 Created mesh info file: \(infoPath)")
            
        } catch {
            print("   ❌ Could not create fallback preview")
        }
    }
}
