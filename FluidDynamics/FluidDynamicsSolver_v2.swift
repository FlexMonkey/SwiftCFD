//
//  FluidDynamicsSolver_v2.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 30/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import Foundation

var frameNumber : Int = 0;

let GRID_WIDTH = 200;
let GRID_HEIGHT = 200;
let DBL_GRID_HEIGHT = Double(GRID_HEIGHT);
let CELL_COUNT = (GRID_WIDTH + 2) * (GRID_HEIGHT + 2);

let dt = 0.15;
let visc = 0.0;
let diff = 0.0;
let linearSolverIterations = 2;

var d = [Double](count: CELL_COUNT, repeatedValue: 0);
var dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
var u = [Double](count: CELL_COUNT, repeatedValue: 0);
var uOld = [Double](count: CELL_COUNT, repeatedValue: 0);
var v = [Double](count: CELL_COUNT, repeatedValue: 0);
var vOld = [Double](count: CELL_COUNT, repeatedValue: 0);
var curl = [Double](count: CELL_COUNT, repeatedValue: 0);

func fluidDynamicsStep() -> [Double]
{
    let startTime : CFAbsoluteTime = CFAbsoluteTimeGetCurrent();
    
    if frameNumber++ < 200
    {
        for i in 50 ..< 150
        {
            for j in 195 ..< 200
            {
                if (arc4random() % 100 > 90)
                {
                    d[getIndex(i, j)] = 1;
                }
            }
        }
    }
    
    velocitySolver();
    densitySolver();
    
    println("CFD SOLVE:" + NSString(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime));
    
    return d;
}

func densitySolver()
{
    d = addSource(d, dOld);

    swapD();
    d = diffuse(0, d, dOld, diff);
    swapD();
    
    d = advect(0, dOld, u, v);
    
    dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
}

func velocitySolver()
{
    //u = addSource(u, uOld);
    //v = addSource(v, vOld);
    
    addSourceUV();
    
    vorticityConfinement();
    
    // u = addSource(u, uOld);
    // v = addSource(v, vOld);
    
    addSourceUV();
    
    buoyancy();
    
    v = addSource(v, vOld);
    
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

func advectUV()
{
    let dt0 = dt * DBL_GRID_HEIGHT;
    
    let dt0x = dt * DBL_GRID_HEIGHT;
    let dt0y = dt * DBL_GRID_HEIGHT;
    
    for var i = GRID_HEIGHT; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = getIndex(i, j);
            
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

func advect (b:Int, d0:[Double], du:[Double], dv:[Double]) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)

    let dt0 = dt * DBL_GRID_HEIGHT;
    
    let dt0x = dt * DBL_GRID_HEIGHT;
    let dt0y = dt * DBL_GRID_HEIGHT;

    for var i = GRID_HEIGHT; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = getIndex(i, j);
            
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
    
    returnArray = setBoundry(b, returnArray);
    
    return returnArray;
}

// project is always on u and v....
func project()
{
    var p = [Double](count: CELL_COUNT, repeatedValue: 0);
    var div = [Double](count: CELL_COUNT, repeatedValue: 0);
    
    for var i = GRID_HEIGHT; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = getIndex(i, j);
            let left = index - 1;
            let right = index + 1;
            let top = index - GRID_WIDTH;
            let bottom = index + GRID_WIDTH;
            
            div[index] = (u[right] - u[left] + v[bottom] - v[top]) * -0.5 / DBL_GRID_HEIGHT;
            
            p[index] = Double(0.0);
        }
        
    }
    
    div = setBoundry(0, div);
    p = setBoundry(0, p);
    
    p = linearSolver(0, p, div, 1, 4);
    
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = getIndex(i, j);
            let left = index - 1;
            let right = index + 1;
            let top = index - GRID_WIDTH;
            let bottom = index + GRID_WIDTH;
            
            u[index] -= 0.5 * DBL_GRID_HEIGHT * (p[right] - p[left]);
            v[index] -= 0.5 * DBL_GRID_HEIGHT * (p[bottom] - p[top]);
        }
    }
    
    u = setBoundry(1, u);
    v = setBoundry(2, v);
}

func diffuseUV()
{
    let a:Double = dt * diff * Double(CELL_COUNT);
    let c:Double = 1 + 4 * a
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        for var i = GRID_WIDTH; i >= 1; i--
        {
            for var j = GRID_HEIGHT; j >= 1; j--
            {
                let index = getIndex(i, j);
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

func linearSolver(b:Int, x:[Double], x0:[Double], a:Double, c:Double) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        for var i = GRID_WIDTH; i >= 1; i--
        {
            for var j = GRID_HEIGHT; j >= 1; j--
            {
                let index = getIndex(i, j);
                let left = index - 1;
                let right = index + 1;
                let top = index - GRID_WIDTH;
                let bottom = index + GRID_WIDTH;
                
                returnArray[index] = (a * ( x[left] + x[right] + x[top] + x[bottom]) + x0[index]) / c;
            }
        }
        returnArray = setBoundry(b, returnArray);
    }
    
    return returnArray;
}

func diffuse(b:Int, c:[Double], c0:[Double], diff:Double) -> [Double]
{
    let a:Double = dt * diff * Double(CELL_COUNT);
    
    let returnArray = linearSolver(b, c, c0, a, 1 + 4 * a);
    
    return returnArray
}

// buoyancy always on vOld...
func buoyancy()
{
    var Tamb:Double = 0;
    var a:Double = 0.000625 //0.000625;
    var b:Double = 0.025 //0.025;

    
    // sum all temperatures
    for var i = 1; i <= GRID_WIDTH; i++
    {
        for var j = 1; j <= GRID_HEIGHT; j++
        {
            Tamb += d[getIndex(i, j)];
        }
    }
    
    // get average temperature
    Tamb /= Double(CELL_COUNT);
    
    // for each cell compute buoyancy force
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = getIndex(i, j);
            
            vOld[index] = a * d[index] + -b * (d[index] - Tamb);
        }
    }
}

// always on vorticityConfinement(uOld, vOld);
func vorticityConfinement()
{
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let tt=curlf(i, j)
            curl[getIndex(i, j)] = tt<0 ? tt * -1:tt;
        }
    }
    
    for var i = 2; i < GRID_WIDTH; i++
    {
        for var j = 2; j < GRID_HEIGHT; j++
        {
            let index = getIndex(i, j);
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
            
            var v = curlf(i, j);
            
            // N x w
            uOld[getIndex(i, j)] = dw_dy * -v;
            vOld[getIndex(i, j)] = dw_dx *  v;
        }
    }
}

func curlf(i:Int, j:Int) -> Double
{
    let index = getIndex(i, j);
    let left = index - 1;
    let right = index + 1;
    let top = index - GRID_WIDTH;
    let bottom = index + GRID_WIDTH;
    
    var du_dy:Double = (u[bottom] - u[top]) * 0.5;
    var dv_dx:Double = (v[right] - v[left]) * 0.5;
    
    return du_dy - dv_dx;
}

func setBoundry(b:Int, x:[Double]) -> [Double]
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

func addSourceUV()
{
    for var i = CELL_COUNT - 1; i >= 0; i--
    {
        u[i] = u[i] + dt * uOld[i];
        v[i] = v[i] + dt * vOld[i];
    }
}

func addSource(x:[Double], x0:[Double]) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var i = CELL_COUNT - 1; i >= 0; i--
    {
        returnArray[i] = x[i] + dt * x0[i];
    }
    
    return returnArray;
}


func swapD()
{
    let tmp = d;
    d = dOld;
    dOld = tmp;
}

func swapU()
{
    let tmp = u;
    u = uOld;
    uOld = tmp;
}

func swapV()
{
    let tmp = v;
    v = vOld;
    vOld = tmp;
}

func getIndex(i : Int, j : Int) -> Int
{
    return i + (GRID_WIDTH) * j;
}