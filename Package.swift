// swift-tools-version:5.7
//  Package.swift
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Metal2DTo3D",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "Metal2DTo3D",
            
        )
    ]
)
