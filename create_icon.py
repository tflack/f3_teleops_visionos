#!/usr/bin/env python3
"""
Script to create app icon from SVG for visionOS
"""

import os
import subprocess
import sys

def create_png_from_svg():
    """Convert SVG to PNG using rsvg-convert or cairosvg"""
    svg_file = "robot_icon.svg"
    png_file = "robot_icon_1024.png"
    
    # Try rsvg-convert first (faster)
    try:
        subprocess.run([
            "rsvg-convert", 
            "-w", "1024", 
            "-h", "1024", 
            "-o", png_file, 
            svg_file
        ], check=True)
        print(f"✅ Created {png_file} using rsvg-convert")
        return png_file
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("rsvg-convert not found, trying cairosvg...")
    
    # Try cairosvg as fallback
    try:
        import cairosvg
        cairosvg.svg2png(url=svg_file, write_to=png_file, output_width=1024, output_height=1024)
        print(f"✅ Created {png_file} using cairosvg")
        return png_file
    except ImportError:
        print("cairosvg not available, trying ImageMagick...")
    
    # Try ImageMagick as last resort
    try:
        subprocess.run([
            "convert", 
            "-background", "transparent",
            "-size", "1024x1024", 
            svg_file, 
            png_file
        ], check=True)
        print(f"✅ Created {png_file} using ImageMagick")
        return png_file
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ No suitable SVG to PNG converter found")
        print("Please install one of: rsvg-convert, cairosvg, or ImageMagick")
        return None

if __name__ == "__main__":
    png_file = create_png_from_svg()
    if png_file and os.path.exists(png_file):
        print(f"🎉 Successfully created {png_file}")
        print("You can now add this to your Xcode project's AppIcon asset catalog")
    else:
        print("❌ Failed to create PNG file")
        sys.exit(1)
