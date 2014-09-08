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

struct FluidDynamicsSolver_v2
{

static var frameNumber : Int = 0;

static let GRID_WIDTH = 200;
static let GRID_HEIGHT = 200;
static let DBL_GRID_HEIGHT = Double(GRID_HEIGHT);
static let CELL_COUNT = (GRID_WIDTH + 2) * (GRID_HEIGHT + 2);

static let dt = 0.1;
static let visc = 0.0;
static let diff = 0.0;
static let linearSolverIterations = 2;

static var d = [Double](count: CELL_COUNT, repeatedValue: 0);
static var dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
static var u = [Double](count: CELL_COUNT, repeatedValue: 0);
static var uOld = [Double](count: CELL_COUNT, repeatedValue: 0);
static var v = [Double](count: CELL_COUNT, repeatedValue: 0);
static var vOld = [Double](count: CELL_COUNT, repeatedValue: 0);
static var curl = [Double](count: CELL_COUNT, repeatedValue: 0);

static func fluidDynamicsStep() -> [Double]
{
    let startTime : CFAbsoluteTime = CFAbsoluteTimeGetCurrent();

    if frameNumber++ < 100
    {
        for i in 90 ..< 110
        {
            for j in 90 ..< 110
            {
                let random = Int(arc4random_uniform(100));
   
                if random > frameNumber
                {
                    d[ViewController.getIndex(i, j: j)] = d[ViewController.getIndex(i, j: j)] + Double(arc4random_uniform(25)) / 25;
                    
                    d[ViewController.getIndex(i, j: j)] = d[ViewController.getIndex(i, j: j)] > 1 ? 1 : d[ViewController.getIndex(i, j: j)];
                    
                    let randomU = (Double(arc4random_uniform(100)) / 100) * (arc4random_uniform(100) >= 50 ? -4.0 : 4.0);
                    u[ViewController.getIndex(i, j: j)] = randomU
                    
                    let randomV = (Double(arc4random_uniform(100)) / 100) * (arc4random_uniform(100) >= 50 ? -4.0 : 4.5);
                    v[ViewController.getIndex(i, j: j)] = randomV
                    
                    let randomCurl = (Double(arc4random_uniform(100)) / 100) * (arc4random_uniform(100) >= 50 ? -4.0 : 4.0);
                    curl[ViewController.getIndex(i, j: j)] = randomCurl
                }
            }
        }
    }

    velocitySolver();
    densitySolver();
    
    println("CFD SOLVE:" + NSString(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime));
    
    return d;
}

static func densitySolver()
{
    d = addSource(d, x0: dOld);

    swapD();
    d = diffuse(0, c: d, c0: dOld, diff: diff);
    swapD();
    
    d = advect(0, d0: dOld, du: u, dv: v);
    
    dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
}

static func velocitySolver()
{
    //u = addSource(u, uOld);
    //v = addSource(v, vOld);
    
    addSourceUV();
    
    vorticityConfinement();
    
    // u = addSource(u, uOld);
    // v = addSource(v, vOld);
    
    addSourceUV();
    
    buoyancy();
    
    v = addSource(v, x0: vOld);
    
    swapU();
    swapV();
    
    diffuseUV();
    
    project();
    
    swapU();
    swapV();

    advectUV();
    
    project()
    
    uOld = [Double](count: CELL_COUNT, repeatedValue: 0);
    vOld = [Double](count: CELL_COUNT, repeatedValue: 0);
}

static func advectUV()
{
    let dt0x = dt * DBL_GRID_HEIGHT;
    let dt0y = dt * DBL_GRID_HEIGHT;
    
    //for var i = GRID_HEIGHT; i >= 1; i--
    for i in 1...GRID_HEIGHT
    {
        //for var j = GRID_HEIGHT; j >= 1; j--
        for j in 1...GRID_HEIGHT
        {
            //let index = ViewController.getIndex(i, j :j);
            let index = GRID_WIDTH * j + i
            
            var x = Double(i) - dt0x * uOld[index];
            var y = Double(j) - dt0y * vOld[index];
            
            if (x > DBL_GRID_HEIGHT + 0.5)
            {
                x = DBL_GRID_HEIGHT + 0.5;
            }
            if (x < 0.5)
            {
                x = 0.5;
            }
            
            if (y > DBL_GRID_HEIGHT + 0.5)
            {
                y = DBL_GRID_HEIGHT + 0.5;
            }
            
            if (y < 0.5)
            {
                y = 0.5;
            }
            
            let i0 = Int(x);
            let i1 = i0 + 1.0;
            
            let j0 = Int(y);
            let j1 = j0 + 1;
            
            let s1 = x - Double(i0);
            let s0 = 1 - s1;
            let t1 = y - Double(j0);
            let t0 = 1 - t1;
            
            let i0j0 = i0 + GRID_WIDTH * j0;
            let i0j1 = i0 + GRID_WIDTH * j1;
            let i1j0 = i1 + GRID_WIDTH * j0;
            let i1j1 = i1 + GRID_WIDTH * j1;
            
            u[index] = s0 * (t0 * u[i0j0] + t1 * uOld[i0j1]) + s1 * (t0 * uOld[i1j0] + t1 * uOld[i1j1]);
            v[index] = s0 * (t0 * v[i0j0] + t1 * vOld[i0j1]) + s1 * (t0 * vOld[i1j0] + t1 * vOld[i1j1]);
        }
    }

}

static func advect (b:Int, d0:[Double], du:[Double], dv:[Double]) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)

    let dt0 = dt * DBL_GRID_HEIGHT;
    
    let dt0x = dt * DBL_GRID_HEIGHT;
    let dt0y = dt * DBL_GRID_HEIGHT;

    for var i = GRID_HEIGHT; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = ViewController.getIndex(i, j: j);
            
            var x = Double(i) - dt0x * du[index];
            var y = Double(j) - dt0y * dv[index];
        
            if (x > DBL_GRID_HEIGHT + 0.5)
            {
                x = DBL_GRID_HEIGHT + 0.5;
            }
            if (x < 0.5)
            {
                x = 0.5;
            }
   
            if (y > DBL_GRID_HEIGHT + 0.5)
            {
                y = DBL_GRID_HEIGHT + 0.5;
            }
            
            if (y < 0.5)
            {
                y = 0.5;
            }
            
            let i0 = Int(x);
            let i1 = i0 + 1.0;
            
            let j0 = Int(y);
            let j1 = j0 + 1;
            
            let s1 = x - Double(i0);
            let s0 = 1 - s1;
            let t1 = y - Double(j0);
            let t0 = 1 - t1;
    
            let i0j0 = i0 + GRID_WIDTH * j0;
            let i0j1 = i0 + GRID_WIDTH * j1;
            let i1j0 = i1 + GRID_WIDTH * j0;
            let i1j1 = i1 + GRID_WIDTH * j1;
            
            var cellValue = s0 * (t0 * d0[i0j0] + t1 * d0[i0j1]) + s1 * (t0 * d0[i1j0] + t1 * d0[i1j1]);
            
            //d[getIndex(i, j)] = d[getIndex(i, j)] * 0.999;

            returnArray[index] = cellValue;
        }
    }
    
    returnArray = setBoundry(b, x: returnArray);
    
    return returnArray;
}

// project is always on u and v....
static func project()
{
    var p = [Double](count: CELL_COUNT, repeatedValue: 0);
    var div = [Double](count: CELL_COUNT, repeatedValue: 0);
    
    for var i = GRID_HEIGHT; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = ViewController.getIndex(i, j : j);
            let left = index - 1;
            let right = index + 1;
            let top = index - GRID_WIDTH;
            let bottom = index + GRID_WIDTH;
            
            div[index] = (u[right] - u[left] + v[bottom] - v[top]) * -0.5 / DBL_GRID_HEIGHT;
            
            p[index] = Double(0.0);
        }
        
    }
    
    div = setBoundry(0, x: div);
    p = setBoundry(0, x: p);
    
    p = linearSolver(0, x: p, x0: div, a: 1, c: 4);
    
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = ViewController.getIndex(i, j : j);
            let left = index - 1;
            let right = index + 1;
            let top = index - GRID_WIDTH;
            let bottom = index + GRID_WIDTH;
            
            u[index] -= 0.5 * DBL_GRID_HEIGHT * (p[right] - p[left]);
            v[index] -= 0.5 * DBL_GRID_HEIGHT * (p[bottom] - p[top]);
        }
    }
    
    u = setBoundry(1, x: u);
    v = setBoundry(2, x: v);
}

static  func diffuseUV()
{
    let a:Double = dt * diff * Double(CELL_COUNT);
    let c:Double = 1 + 4 * a
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        for var i = GRID_WIDTH; i >= 1; i--
        {
            for var j = GRID_HEIGHT; j >= 1; j--
            {
                let index = ViewController.getIndex(i, j: j);
                let left = index - 1;
                let right = index + 1;
                let top = index - GRID_WIDTH;
                let bottom = index + GRID_WIDTH;
                
                u[index] = (a * ( u[left] + u[right] + u[top] + u[bottom]) + uOld[index]) / c;
                
                v[index] = (a * ( v[left] + v[right] + v[top] + v[bottom]) + vOld[index]) / c;
            }
        }
    }
}

static func linearSolver(b:Int, x:[Double], x0:[Double], a:Double, c:Double) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        for var i = GRID_WIDTH; i >= 1; i--
        {
            for var j = GRID_HEIGHT; j >= 1; j--
            {
                let index = ViewController.getIndex(i, j: j);
                let left = index - 1;
                let right = index + 1;
                let top = index - GRID_WIDTH;
                let bottom = index + GRID_WIDTH;
                
                returnArray[index] = (a * ( x[left] + x[right] + x[top] + x[bottom]) + x0[index]) / c;
            }
        }
        returnArray = setBoundry(b, x: returnArray);
    }
    
    return returnArray;
}

static func diffuse(b:Int, c:[Double], c0:[Double], diff:Double) -> [Double]
{
    let a:Double = dt * diff * Double(CELL_COUNT);
    
    let returnArray = linearSolver(b, x: c, x0: c0, a: a, c: 1 + 4 * a);
    
    return returnArray
}

// buoyancy always on vOld...
static func buoyancy()
{
    var Tamb:Double = 0;
    var a:Double = 0.000625 //0.000625;
    var b:Double = 0.025 //0.025;

    
    // sum all temperatures
    for var i = 1; i <= GRID_WIDTH; i++
    {
        for var j = 1; j <= GRID_HEIGHT; j++
        {
            Tamb += d[ViewController.getIndex(i, j: j)];
        }
    }
    
    // get average temperature
    Tamb /= Double(CELL_COUNT);
    
    // for each cell compute buoyancy force
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = ViewController.getIndex(i, j: j);
            
            vOld[index] = a * d[index] + -b * (d[index] - Tamb);
        }
    }
}

// always on vorticityConfinement(uOld, vOld);
static func vorticityConfinement()
{
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let tt=curlf(i, j: j)
            curl[ViewController.getIndex(i, j: j)] = tt<0 ? tt * -1:tt;
        }
    }
    
    for var i = 2; i < GRID_WIDTH; i++
    {
        for var j = 2; j < GRID_HEIGHT; j++
        {
            let index = ViewController.getIndex(i, j: j);
            let left = index - 1;
            let right = index + 1;
            let top = index - GRID_WIDTH;
            let bottom = index + GRID_WIDTH;
            
            // Find derivative of the magnitude (n = del |w|)
            var dw_dx = (curl[right] - curl[left]) * 0.5;
            var dw_dy = (curl[bottom] - curl[top]) * 0.5;

            let length = hypot(dw_dx, dw_dy) + 0.000001;
            
            // N = ( n/|n| )
            dw_dx /= length;
            dw_dy /= length;
            
            var v = curlf(i, j: j);
            
            // N x w
            uOld[ViewController.getIndex(i, j: j)] = dw_dy * -v;
            vOld[ViewController.getIndex(i, j: j)] = dw_dx *  v;
        }
    }
}

static func curlf(i:Int, j:Int) -> Double
{
    let index = ViewController.getIndex(i, j: j);
    let left = index - 1;
    let right = index + 1;
    let top = index - GRID_WIDTH;
    let bottom = index + GRID_WIDTH;
    
    var du_dy:Double = (u[bottom] - u[top]) * 0.5;
    var dv_dx:Double = (v[right] - v[left]) * 0.5;
    
    return du_dy - dv_dx;
}

static func setBoundry(b:Int, x:[Double]) -> [Double]
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

static func addSourceUV()
{
    for var i = CELL_COUNT - 1; i >= 0; i--
    {
        u[i] = u[i] + dt * uOld[i];
        v[i] = v[i] + dt * vOld[i];
    }
}

static func addSource(x:[Double], x0:[Double]) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var i = CELL_COUNT - 1; i >= 0; i--
    {
        returnArray[i] = x[i] + dt * x0[i];
    }
    
    return returnArray;
}


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
static func getIndex(i : Int, j : Int) -> Int
{
    return i + 1 + (FluidDynamicsSolver_v2.GRID_WIDTH + 2) * j;
}
}