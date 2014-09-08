//
//  FluidDynamicsSolver_v2.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 30/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//
//  CFD Solver based on this AS3 implementation from Oaxoa
//  http://blog.oaxoa.com/2008/01/21/actionscript-3-fluids-simulation/
//
//  Which is based on Jos Stam's paper, "Real Time Fluid Dynamics for Games"
//  http://www.dgp.toronto.edu/people/stam/reality/Research/pdf/GDC03.pdf
//
//  Used by me many times
//  http://flexmonkey.blogspot.co.uk/search/label/Computational%20Fluid%20Dynamics
//
//  Thanks to Joseph Lord for hints on optimsation
//  http://blog.human-friendly.com/

import Foundation

let GRID_WIDTH = 200;
let GRID_HEIGHT = 200;
let LINE_STRIDE = GRID_HEIGHT + 2
let DBL_GRID_HEIGHT = Double(GRID_HEIGHT);
let CELL_COUNT = (GRID_WIDTH + 2) * (GRID_HEIGHT + 2);

let dt = 0.1;
let visc = 0.0;
let diff = 0.0;
let linearSolverIterations = 2;


struct FluidDynamicsSolver_v2
{

static var frameNumber : Int = 0;



static var d = [Double](count: CELL_COUNT, repeatedValue: 0);
static var dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
static var u = [Double](count: CELL_COUNT, repeatedValue: 0);
    //static var uOld = [Double](count: CELL_COUNT, repeatedValue: 0);
static var v = [Double](count: CELL_COUNT, repeatedValue: 0);
    //static var vOld = [Double](count: CELL_COUNT, repeatedValue: 0);
static var curl = [Double](count: CELL_COUNT, repeatedValue: 0);

static func fluidDynamicsStep() -> [Double]
{
    let startTime : CFAbsoluteTime = CFAbsoluteTimeGetCurrent();

    if frameNumber++ < 100
    {
        for j in (GRID_HEIGHT * 9)/20 ..< (GRID_HEIGHT * 11)/20
        {
            for i in (GRID_WIDTH * 9)/20 ..< (GRID_WIDTH * 11)/20
            {
                let random = Int(arc4random_uniform(100));
   
                if random > frameNumber
                {
                    d[getIndex(i, j: j)] = d[getIndex(i, j: j)] + Double(arc4random_uniform(25)) / 25;
                    
                    d[getIndex(i, j: j)] = d[getIndex(i, j: j)] > 1 ? 1 : d[getIndex(i, j: j)];
                    
                    let randomU = (Double(arc4random_uniform(100)) / 100) * (arc4random_uniform(100) >= 50 ? -4.0 : 4.0);
                    u[getIndex(i, j: j)] = randomU
                    
                    let randomV = (Double(arc4random_uniform(100)) / 100) * (arc4random_uniform(100) >= 50 ? -4.0 : 4.5);
                    v[getIndex(i, j: j)] = randomV
                    
                    let randomCurl = (Double(arc4random_uniform(100)) / 100) * (arc4random_uniform(100) >= 50 ? -4.0 : 4.0);
                    curl[getIndex(i, j: j)] = randomCurl
                }
            }
        }
    }

    (u, v, curl) = velocitySolver(d: d, u: u, v: v, curl: curl)
    densitySolver(u: u, v: v, d: &d, dOld: &dOld);
    
    println("CFD SOLVE:" + NSString(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime));
    
    return d;
}
}
func densitySolver(#u: [Double], #v: [Double], inout #d:[Double], inout #dOld: [Double])
{
    d = addSource(d, x0: dOld);

    swap(&d, &dOld);
    d = diffuse(0, c: d, c0: dOld, diff: diff);
    swap(&d, &dOld);
    
    d = advect(0, d0: dOld, du: u, dv: v);
    
    dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
}

func velocitySolver(#d:[Double], #u: [Double], #v: [Double], #curl:[Double])->(u: [Double], v: [Double], curl: [Double])
{
    //u = addSource(u, uOld);
    //v = addSource(v, vOld);
    
    // Redundant
    //addSourceUV(uOld, vOld, &u, &v);
    
    var uvcReturn = vorticityConfinement(u: u, v: v, curl: curl);
    // u = addSource(u, uOld);
    // v = addSource(v, vOld);
    
    let uv0 = addSourceUV(uvcReturn.uReturn, uvcReturn.vReturn, u, v);
    
    var uOld = uvcReturn.uReturn
    var vOld = buoyancy(d);
    
    let v0 = addSource(uv0.v, x0: vOld);
    
    let uv1 = diffuseUV(uOld: uv0.u, vOld: v0, u: uOld, v: vOld);
    
    let uv2 = project(u: uv1.u, v: uv1.v);

    let uv3 = advectUV(uOld: uv2.u, vOld: uv2.v, u: uOld, v: vOld);
    
    let uv4 = project(u: uv3.u, v: uv3.v);
    
    return (u: uv4.u, v: uv4.v, curl: uvcReturn.cReturn)
}

func advectUV(#uOld:[Double], #vOld:[Double], #u: [Double], #v: [Double])->(u: [Double], v: [Double])
{
    let dt0x = dt * DBL_GRID_HEIGHT;
    let dt0y = dt * DBL_GRID_HEIGHT;
    
    var uOut = [Double](count: CELL_COUNT, repeatedValue: 0);
    var vOut = [Double](count: CELL_COUNT, repeatedValue: 0);
    
    //for var i = GRID_HEIGHT; i >= 1; i--
    for j in 0..<GRID_HEIGHT
    {
        //for var j = GRID_HEIGHT; j >= 1; j--
        for i in 0..<GRID_WIDTH
        {
            let index = getIndex(i, j :j);
            //let index = GRID_WIDTH * j + i
            
            var x = Double(i) - dt0x * uOld[index];
            var y = Double(j) - dt0y * vOld[index];
            
            x = min(x, DBL_GRID_HEIGHT + 0.5)
            x = max(x, 0.5)
            y = min(y, DBL_GRID_HEIGHT + 0.5)
            y = max(y, 0.5)
            
            let i0 = Int(x);
            let i1 = i0 + 1.0;
            
            let j0 = Int(y);
            let j1 = j0 + 1;
            
            let s1 = x - Double(i0);
            let s0 = 1 - s1;
            let t1 = y - Double(j0);
            let t0 = 1 - t1;
            
            let i0j0 = i0 + LINE_STRIDE * j0;
            let i0j1 = i0 + LINE_STRIDE * j1;
            let i1j0 = i1 + LINE_STRIDE * j0;
            let i1j1 = i1 + LINE_STRIDE * j1;
            
            uOut[index] = s0 * (t0 * uOld[i0j0] + t1 * uOld[i0j1]) + s1 * (t0 * uOld[i1j0] + t1 * uOld[i1j1]);
            vOut[index] = s0 * (t0 * vOld[i0j0] + t1 * vOld[i0j1]) + s1 * (t0 * vOld[i1j0] + t1 * vOld[i1j1]);
        }
    }
    return (u: uOut, v: vOut)
}

func advect (b:Int, #d0:[Double], #du:[Double], #dv:[Double]) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)

    let dt0 = dt * DBL_GRID_HEIGHT;
    
    let dt0x = dt * DBL_GRID_HEIGHT;
    let dt0y = dt * DBL_GRID_HEIGHT;

    //for var i = GRID_HEIGHT; i >= 1; i--
    for j in 0..<GRID_HEIGHT
    {
        //        for var j = GRID_HEIGHT; j >= 1; j--
        for i in 0..<GRID_WIDTH
        {
            let index = getIndex(i, j: j);
            
            var x = Double(i) - dt0x * du[index];
            var y = Double(j) - dt0y * dv[index];
        
            x = min(x, DBL_GRID_HEIGHT + 0.5)
            x = max(x, 0.5)
            y = min(y, DBL_GRID_HEIGHT + 0.5)
            y = max(y, 0.5)
            
            let i0 = Int(x);
            let i1 = i0 + 1.0;
            
            let j0 = Int(y);
            let j1 = j0 + 1;
            
            let s1 = x - Double(i0);
            let s0 = 1 - s1;
            let t1 = y - Double(j0);
            let t0 = 1 - t1;
    
            let i0j0 = i0 + LINE_STRIDE * j0;
            let i0j1 = i0 + LINE_STRIDE * j1;
            let i1j0 = i1 + LINE_STRIDE * j0;
            let i1j1 = i1 + LINE_STRIDE * j1;
            
            var cellValue = s0 * (t0 * d0[i0j0] + t1 * d0[i0j1]) + s1 * (t0 * d0[i1j0] + t1 * d0[i1j1]);
            
            //d[getIndex(i, j)] = d[getIndex(i, j)] * 0.999;

            returnArray[index] = cellValue;
        }
    }
    
    returnArray = setBoundry(b, x: returnArray);
    
    return returnArray;
}


// project is always on u and v....
func project(u uIn:[Double], v vIn:[Double])->(u:[Double], v:[Double])
{
    var p = [Double](count: CELL_COUNT, repeatedValue: 0);
    var div = [Double](count: CELL_COUNT, repeatedValue: 0);
    //for var j = GRID_HEIGHT; j >= 1; j--
    for j in 0..<GRID_HEIGHT
    {
        //for var i = GRID_WIDTH; i >= 1; i--
        for i in 0..<GRID_WIDTH
        {
            let index = getIndex(i, j : j);
            let left = index - 1;
            let right = index + 1;
            let top = index - LINE_STRIDE;
            let bottom = index + LINE_STRIDE;
            
            div[index] = (uIn[right] - uIn[left] + vIn[bottom] - vIn[top]) * -0.5 / DBL_GRID_HEIGHT;
            
            p[index] = Double(0.0);
        }
        
    }
    
    div = setBoundry(0, x: div);
    p = setBoundry(0, x: p);
    
    p = linearSolver(0, x: p, x0: div, a: 1, c: 4);
    
    var u = [Double](count: CELL_COUNT, repeatedValue: 0);
    var v = [Double](count: CELL_COUNT, repeatedValue: 0);
    
    //for var j = GRID_HEIGHT; j >= 1; j--
    for j in 0..<GRID_HEIGHT
    {
        //            for var i = GRID_WIDTH; i >= 1; i--
        for i in 0..<GRID_WIDTH
        {
            let index = getIndex(i, j : j);
            let left = index - 1;
            let right = index + 1;
            let top = index - LINE_STRIDE;
            let bottom = index + LINE_STRIDE;
            
            u[index] -= 0.5 * DBL_GRID_HEIGHT * (p[right] - p[left]);
            v[index] -= 0.5 * DBL_GRID_HEIGHT * (p[bottom] - p[top]);
        }
    }
    
    u = setBoundry(1, x: u);
    v = setBoundry(2, x: v);
    return (u: u, v: v)
}

func diffuseUV(#uOld:[Double], #vOld:[Double], #u:[Double], #v:[Double])->(u: [Double], v: [Double])
{
    let a:Double = dt * diff * Double(CELL_COUNT);
    let c:Double = 1 + 4 * a
    
    var returnU = u
    var returnV = v
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        //for var i = GRID_WIDTH; i >= 1; i--
        for j in 0..<GRID_HEIGHT
        {
            //for var j = GRID_HEIGHT; j >= 1; j--
            for i in 0..<GRID_WIDTH
            {
                let index = getIndex(i, j: j);
                let left = index - 1;
                let right = index + 1;
                let top = index - LINE_STRIDE;
                let bottom = index + LINE_STRIDE;
                
                returnU[index] = (a * ( returnU[left] + returnU[right] + returnU[top] + returnU[bottom]) + uOld[index]) / c;
                
                returnV[index] = (a * ( returnV[left] + returnV[right] + returnV[top] + returnV[bottom]) + vOld[index]) / c;
            }
        }
    }
    return (u: returnU, v: returnV)
}

func diffuse(b:Int, #c:[Double], #c0:[Double], #diff:Double) -> [Double]
{
    let a:Double = dt * diff * Double(CELL_COUNT);
    
    let returnArray = linearSolver(b, x: c, x0: c0, a: a, c: 1 + 4 * a);
    
    return returnArray
}



// always on vorticityConfinement(uOld, vOld);
func vorticityConfinement(#u:[Double], #v:[Double], #curl:[Double])->(uReturn:[Double], vReturn:[Double], cReturn: [Double])
{
    var uReturn = [Double](count: CELL_COUNT, repeatedValue: 0);
    var vReturn = [Double](count: CELL_COUNT, repeatedValue: 0);
    var curlReturn = [Double](count: CELL_COUNT, repeatedValue: 0);
    //for var i = GRID_WIDTH; i >= 1; i--
    for j in 0..<GRID_HEIGHT
    {
        //        for var j = GRID_HEIGHT; j >= 1; j--
        for i in 0..<GRID_WIDTH
        {
            let tt=curlf(i, j: j, u: u, v: v)
            curlReturn[getIndex(i, j: j)] = tt<0 ? tt * -1:tt;
        }
    }
    
    //for var i = 2; i < GRID_WIDTH; i++
    for j in 0..<GRID_HEIGHT
    {
        //for var j = 2; j < GRID_HEIGHT; j++
        for i in 0..<GRID_WIDTH
        {
            let index = getIndex(i, j: j);
            let left = index - 1;
            let right = index + 1;
            let top = index - LINE_STRIDE;
            let bottom = index + LINE_STRIDE;
            
            // Find derivative of the magnitude (n = del |w|)
            var dw_dx = (curl[right] - curl[left]) * 0.5;
            var dw_dy = (curl[bottom] - curl[top]) * 0.5;

            let length = hypot(dw_dx, dw_dy) + 0.000001;
            
            // N = ( n/|n| )
            dw_dx /= length;
            dw_dy /= length;
            
            var v0 = curlf(i, j: j, u: u, v: v);
            
            // N x w
            uReturn[getIndex(i, j: j)] = dw_dy * -v0;
            vReturn[getIndex(i, j: j)] = dw_dx *  v0;
        }
    }
    return (uReturn: uReturn, vReturn: vReturn, cReturn: curlReturn)
}

/*
static func swapD()
{
    let tmp = d;
    d = dOld;
    dOld = tmp;
}

static func swapU()
{
    let tmp = u;
    u = uOld;
    uOld = tmp;
}

static func swapV()
{
    let tmp = v;
    v = vOld;
    vOld = tmp;
}

}
*/
// buoyancy always on vOld...
func buoyancy(d:[Double])->[Double]
{
    var Tamb:Double = 0;
    var a:Double = 0.000625 //0.000625;
    var b:Double = 0.025 //0.025;
    var returnV = [Double](count: CELL_COUNT, repeatedValue: 0);
    
    // sum all temperatures
    for var i = 1; i <= GRID_WIDTH; i++
    {
        for var j = 1; j <= GRID_HEIGHT; j++
        {
            Tamb += d[getIndex(i, j: j)];
        }
    }
    
    // get average temperature
    Tamb /= Double(CELL_COUNT);
    
    // for each cell compute buoyancy force
    //for var i = GRID_WIDTH; i >= 1; i--
    for j in 0..<GRID_WIDTH
    {
        //        for var j = GRID_HEIGHT; j >= 1; j--
        for i in 0..<GRID_HEIGHT
        {
            let index = getIndex(i, j: j);
            
            returnV[index] = a * d[index] + -b * (d[index] - Tamb);
        }
    }
    return returnV
}


// This costs 2 full array copies!!!
func swap(inout a:[Double], inout b:[Double]) {
    let tmp = a
    a = b
    b = tmp
}

func linearSolver(b:Int, #x:[Double], #x0:[Double], #a:Double, #c:Double) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        //for var i = GRID_WIDTH; i >= 1; i--
        for j in 0..<GRID_HEIGHT
        {
            //for var j = GRID_HEIGHT; j >= 1; j--
            for i in 0..<GRID_WIDTH
            {
                let index = getIndex(i, j: j);
                let left = index - 1;
                let right = index + 1;
                let top = index - LINE_STRIDE;
                let bottom = index + LINE_STRIDE;
                
                returnArray[index] = (a * ( x[left] + x[right] + x[top] + x[bottom]) + x0[index]) / c;
            }
        }
        returnArray = setBoundry(b, x: returnArray);
    }
    
    return returnArray;
}

func setBoundry(b:Int, #x:[Double]) -> [Double]
{
    var returnArray = x;
    
    return returnArray;
    
    /*
    for var i = GRID_HEIGHT; i >= 1; i--
    {
    if(b==1)
    {
    returnArray[getIndex(  0, i  )] = -x[getIndex(1, i)];
    returnArray[getIndex(GRID_HEIGHT+1, i  )] = -x[getIndex(GRID_HEIGHT, i)];
    }
    else
    {
    returnArray[getIndex(  0, i  )] = x[getIndex(1, i)];
    returnArray[getIndex(GRID_HEIGHT+1, i  )] = x[getIndex(GRID_HEIGHT, i)];
    }
    
    if(b==2)
    {
    returnArray[getIndex(  i, 0  )] = -x[getIndex(i, 1)];
    returnArray[getIndex(  i, GRID_HEIGHT+1)] = -x[getIndex(i, GRID_HEIGHT)];
    }
    else
    {
    returnArray[getIndex(  i, 0  )] = x[getIndex(i, 1)];
    returnArray[getIndex(  i, GRID_HEIGHT+1)] = x[getIndex(i, GRID_HEIGHT)];
    }
    }
    
    returnArray[getIndex(0, 0)] = 0.5 * (x[getIndex(1, 0  )] + x[getIndex(0, 1)]);
    returnArray[getIndex(0, GRID_HEIGHT+1)] = 0.5 * (x[getIndex(1, GRID_HEIGHT+1)] + x[getIndex(  0, GRID_HEIGHT)]);
    returnArray[getIndex(GRID_HEIGHT+1, 0)] = 0.5 * (x[getIndex(GRID_HEIGHT, 0)] + x[getIndex(GRID_HEIGHT+1, 1)]);
    returnArray[getIndex(GRID_HEIGHT+1, GRID_HEIGHT+1)] = 0.5 * (x[getIndex(GRID_HEIGHT, GRID_HEIGHT+1)] + x[getIndex(GRID_HEIGHT+1, GRID_HEIGHT)]);
    
    return returnArray;
    */
}

func curlf(i:Int, #j:Int, #u: [Double], #v: [Double]) -> Double
{
    let index = getIndex(i, j: j);
    let left = index - 1;
    let right = index + 1;
    let top = index - LINE_STRIDE;
    let bottom = index + LINE_STRIDE;
    
    var du_dy:Double = (u[bottom] - u[top]) * 0.5;
    var dv_dx:Double = (v[right] - v[left]) * 0.5;
    
    return du_dy - dv_dx;
}


// No performance cost to pass as arguments makes it testable and performance testable.
func addSourceUV(uOld: [Double], vOld:[Double], u:[Double], v:[Double])->(u: [Double], v: [Double]) {
    var uOut = [Double](count: CELL_COUNT, repeatedValue: 0);
    var vOut = [Double](count: CELL_COUNT, repeatedValue: 0);
    for var i = CELL_COUNT - 1; i >= 0; i--
    {
        uOut[i] = u[i] + dt * uOld[i];
        vOut[i] = v[i] + dt * vOld[i];
    }
    return (u: uOut, v: vOut)
}

private func addSource(x:[Double], #x0:[Double]) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var i = CELL_COUNT - 1; i >= 0; i--
    {
        returnArray[i] = x[i] + dt * x0[i];
    }
    
    return returnArray;
}

func getIndex(i : Int, #j : Int) -> Int
{
    return i + 1 + LINE_STRIDE * (j + 1);
}