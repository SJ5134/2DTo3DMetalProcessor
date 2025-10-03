#
//  run.sh
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

#!/bin/bash
set -e

echo "🚀 Metal 2D to 3D Converter"
echo "==========================="

# Build first
echo "📦 Building project..."
swift build -c release

# Create necessary directories
mkdir -p Assets/TestImages
mkdir -p Outputs/DepthMaps
mkdir -p Outputs/Meshes
mkdir -p Outputs/Renders

# Check if test images exist, create sample if not
if [ ! -f "Assets/TestImages/one.jpg" ]; then
    echo "📸 Creating sample test images..."
    # Create a simple test image using sips (built into macOS)
    mkdir -p Assets/TestImages
    # Create a simple color image using sips
    sips --setProperty format jpeg --setProperty formatOptions 80 -s width 512 -s height 512 /System/Library/Desktop\ Pictures/Abstract.jpg --out Assets/TestImages/one.jpg 2>/dev/null || echo "📝 Using fallback test mode"
fi

echo "✅ Setup complete!"
echo ""
echo "🎯 Running Metal 2D to 3D pipeline..."
./.build/release/Metal2DTo3D

echo ""
echo "📁 Output files saved in: ./Outputs/"
ls -la Outputs/
