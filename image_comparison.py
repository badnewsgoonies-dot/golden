#!/usr/bin/env python3
"""
Image Comparison Tool
Compares two images and provides detailed analysis of differences.
"""

import cv2
import numpy as np
import sys
from pathlib import Path

def load_image(image_path):
    """Load an image and return it as numpy array"""
    try:
        img = cv2.imread(str(image_path))
        if img is None:
            raise ValueError(f"Could not load image: {image_path}")
        return img
    except Exception as e:
        print(f"Error loading image {image_path}: {e}")
        return None

def compare_images(img1_path, img2_path):
    """Compare two images and return detailed analysis"""
    
    # Load images
    img1 = load_image(img1_path)
    img2 = load_image(img2_path)
    
    if img1 is None or img2 is None:
        return None
    
    # Get image dimensions
    h1, w1, c1 = img1.shape
    h2, w2, c2 = img2.shape
    
    print(f"Image 1 ({img1_path.name}): {w1}x{h1}, {c1} channels")
    print(f"Image 2 ({img2_path.name}): {w2}x{h2}, {c2} channels")
    
    # Resize images to same dimensions if different
    if (h1, w1) != (h2, w2):
        print(f"Images have different dimensions. Resizing to match...")
        target_h, target_w = min(h1, h2), min(w1, w2)
        img1 = cv2.resize(img1, (target_w, target_h))
        img2 = cv2.resize(img2, (target_w, target_h))
        print(f"Resized both images to: {target_w}x{target_h}")
    
    # Convert to grayscale for comparison
    gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
    gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)
    
    # Calculate difference
    diff = cv2.absdiff(gray1, gray2)
    
    # Calculate statistics
    total_pixels = diff.shape[0] * diff.shape[1]
    different_pixels = np.count_nonzero(diff)
    similarity_percentage = ((total_pixels - different_pixels) / total_pixels) * 100
    
    # Calculate mean absolute difference
    mean_diff = np.mean(diff)
    max_diff = np.max(diff)
    
    # Find contours of differences
    thresh = cv2.threshold(diff, 30, 255, cv2.THRESH_BINARY)[1]
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Create visualization
    diff_colored = cv2.applyColorMap(diff, cv2.COLORMAP_HOT)
    
    # Save difference visualization
    output_path = Path("difference_visualization.png")
    cv2.imwrite(str(output_path), diff_colored)
    
    # Create side-by-side comparison
    comparison = np.hstack([img1, img2, diff_colored])
    comparison_path = Path("side_by_side_comparison.png")
    cv2.imwrite(str(comparison_path), comparison)
    
    return {
        'similarity_percentage': similarity_percentage,
        'different_pixels': different_pixels,
        'total_pixels': total_pixels,
        'mean_difference': mean_diff,
        'max_difference': max_diff,
        'num_difference_regions': len(contours),
        'output_files': [output_path, comparison_path]
    }

def main():
    if len(sys.argv) != 3:
        print("Usage: python image_comparison.py <image1> <image2>")
        print("Example: python image_comparison.py Current.png Desired.png")
        return
    
    img1_path = Path(sys.argv[1])
    img2_path = Path(sys.argv[2])
    
    if not img1_path.exists():
        print(f"Error: {img1_path} does not exist")
        return
    
    if not img2_path.exists():
        print(f"Error: {img2_path} does not exist")
        return
    
    print("=" * 60)
    print("IMAGE COMPARISON ANALYSIS")
    print("=" * 60)
    
    result = compare_images(img1_path, img2_path)
    
    if result is None:
        print("Comparison failed!")
        return
    
    print("\nRESULTS:")
    print("-" * 30)
    print(f"Similarity: {result['similarity_percentage']:.2f}%")
    print(f"Different pixels: {result['different_pixels']:,} out of {result['total_pixels']:,}")
    print(f"Mean difference: {result['mean_difference']:.2f}")
    print(f"Max difference: {result['max_difference']}")
    print(f"Number of difference regions: {result['num_difference_regions']}")
    
    print(f"\nOutput files created:")
    for file_path in result['output_files']:
        print(f"  - {file_path}")
    
    print("\n" + "=" * 60)
    
    # Interpretation
    if result['similarity_percentage'] > 99:
        print("CONCLUSION: Images are virtually identical!")
    elif result['similarity_percentage'] > 95:
        print("CONCLUSION: Images are very similar with minor differences.")
    elif result['similarity_percentage'] > 90:
        print("CONCLUSION: Images are mostly similar with some noticeable differences.")
    elif result['similarity_percentage'] > 80:
        print("CONCLUSION: Images have significant differences.")
    else:
        print("CONCLUSION: Images are quite different.")

if __name__ == "__main__":
    main()