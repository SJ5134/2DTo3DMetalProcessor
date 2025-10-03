# Metal2DTo3D 🚀

**GPU-Accelerated 2D to 3D Conversion Pipeline**  
*Transforming images into textured 3D models using Apple's Metal framework*

![Metal](https://img.shields.io/badge/Metal-GPU%20Compute-blue)
![Swift](https://img.shields.io/badge/Swift-5.7+-orange)
![macOS](https://img.shields.io/badge/macOS-12.0+-silver)
![License](https://img.shields.io/badge/License-MIT-green)

## 🎯 Capstone Project

This project demonstrates advanced **GPU programming** and **parallel computing** using Apple's Metal framework for real-time 2D to 3D conversion. Built as a capstone project showcasing professional-grade GPU acceleration techniques.

## ✨ Features

### 🎨 Core Pipeline
- **GPU-Accelerated Depth Estimation** - Real-time depth map generation using Metal compute shaders
- **AI-Enhanced Segmentation** - Vision framework integration for subject detection
- **Automatic 3D Mesh Generation** - Convert depth maps to textured 3D models
- **Multi-Format Export** - OBJ, USDZ, and material files for industry compatibility

### 🚀 GPU Optimization
- **Massive Parallelism** - 262,144+ concurrent threads for 512x512 images
- **Memory-Efficient** - Optimized texture and buffer management
- **Real-Time Performance** - Sub-second processing on Apple Silicon
- **Advanced Algorithms** - Multi-technique depth fusion and edge detection

### 🎮 Output Quality
- **Photorealistic Textures** - Automatic UV mapping and texture projection
- **Professional 3D Models** - Industry-standard OBJ format with materials
- **AR-Ready Files** - USDZ format for Apple ecosystem integration
- **High-Fidelity Meshes** - Adaptive triangle density and smooth surfaces


### Sample Outputs
- **Depth Maps**: AI-enhanced depth estimation
- **3D Meshes**: High-quality geometry with proper topology  
- **Textured Models**: Photorealistic surface mapping
- **AR Previews**: Interactive USDZ files

## 🚀 Quick Start

### Prerequisites
- macOS 12.0 or later
- Xcode 14.0 or later
- Apple Silicon (M1/M2) or Intel with Metal support


### Build the Project
- swift build -c release
- ./.build/release/Metal2DTo3D


## Project Structure
- Metal2DTo3D/
 
  ─ Sources/
  
         |── Metal2DTo3D/
  
           ├── main.swift                 # Pipeline orchestration
    
           ├── MetalRenderer.swift        # GPU compute management
    
           ├── VisionMetalBridge.swift    # AI vision integration
    
           ├── ImageProcessor.swift       # Processing pipeline
    
           ├── MeshViewer.swift           # 3D visualization
    
           └── Types.swift               # Data structures
  
  ── Assets/
  
       |── TestImages                   # Input images
  
  ── Outputs/                          # Generated files
  
      ├── DepthMaps/                    # Depth visualizations
      
      ├── Meshes/                       # 3D model files (OBJ)
      
    ├── Renders/                      # Textured previews (USDZ)
    
    └── Analysis/                     # Performance reports

  
