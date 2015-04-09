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
private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(CGImageAlphaInfo.PremultipliedFirst.rawValue)

private func imageFromARGB32Bitmap(pixels:[PixelData], width:Int, height:Int)->UIImage
{
    let bitsPerComponent:Int = 8
    let bitsPerPixel:Int = 32
    
    var data = pixels // Copy to mutable []
    let providerRef = CGDataProviderCreateWithCFData(NSData(bytes: &data, length: data.count * sizeof(PixelData)))
    
    let cgim = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, width * Int(sizeof(PixelData)), rgbColorSpace,	bitmapInfo, providerRef, nil, true, kCGRenderingIntentDefault)
    
    return UIImage(CGImage: cgim)!;
}

func renderFluidDynamics(densities : [Double]) -> UIImage
{
    var pixelArray = [PixelData](count: densities.count, repeatedValue: PixelData(a: 255, r:0, g: 0, b: 0));
    
    for var i = 0; i < FluidDynamicsSolver_v2.CELL_COUNT; i++
    {
        let pixelValue = UInt8(255 * densities[i]);
        
        pixelArray[i].r = pixelValue;
        pixelArray[i].g = pixelValue;
        pixelArray[i].b = pixelValue;
    }
    
    let outputImage = imageFromARGB32Bitmap(pixelArray, FluidDynamicsSolver_v2.GRID_WIDTH, FluidDynamicsSolver_v2.GRID_HEIGHT)
    
    return outputImage;
}

struct PixelData
{
    var a:UInt8 = 255
    var r:UInt8
    var g:UInt8
    var b:UInt8
}