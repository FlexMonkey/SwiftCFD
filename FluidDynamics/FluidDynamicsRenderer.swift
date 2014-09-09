//
//  FluidDynamicsRenderer.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 30/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//
//
//  Based on work by Joseph Lord 
//  http://blog.human-friendly.com/

import Foundation
import UIKit

private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(CGImageAlphaInfo.PremultipliedFirst.toRaw())

private func imageFromARGB32Bitmap(pixels:[PixelData], width:UInt, height:UInt)->UIImage
{
    let bitsPerComponent:UInt = 8
    let bitsPerPixel:UInt = 32
    
    var data = pixels // Copy to mutable []
    let providerRef = CGDataProviderCreateWithCFData(NSData(bytes: &data, length: data.count * sizeof(PixelData)))
    
    let cgim = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, width * UInt(sizeof(PixelData)), rgbColorSpace,	bitmapInfo, providerRef, nil, true, kCGRenderingIntentDefault)
    
    return UIImage(CGImage: cgim);
}

func renderFluidDynamics(densities : [Double]) -> UIImage
{
    var pixelArray = [PixelData](count: GRID_HEIGHT * GRID_WIDTH, repeatedValue: PixelData(a: 255, r:0, g: 0, b: 0));
 
    //for var i = 0; i < FluidDynamicsSolver_v2.CELL_COUNT; i++
    var outIndex = 0
    for j in 0..<GRID_HEIGHT {
    for i in 0..<GRID_WIDTH
    {
        let index = ViewController.getIndex(i, j: j)
        let pixelValue = UInt8(255 * densities[index]);
        
        pixelArray[outIndex].r = pixelValue;
        pixelArray[outIndex].g = pixelValue;
        pixelArray[outIndex++].b = pixelValue;
    }
    }
    
    let outputImage = imageFromARGB32Bitmap(pixelArray, UInt(GRID_WIDTH), UInt(GRID_HEIGHT))
    
    return outputImage;
}

struct PixelData
{
    var a:UInt8 = 255
    var r:UInt8
    var g:UInt8
    var b:UInt8
}