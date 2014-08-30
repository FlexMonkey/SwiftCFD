//
//  FluidDynamicsSolver_v2.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 30/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import Foundation

var ii : Int = 0;

let GRID_WIDTH = 100;
let GRID_HEIGHT = 100;
let CELL_COUNT = (GRID_WIDTH + 2) * (GRID_HEIGHT + 2);

let dt = 0.52;
let visc = 0.0;
let diff = 0.0;

var d = [Double](count: CELL_COUNT, repeatedValue: 0);
var dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
var u = [Double](count: CELL_COUNT, repeatedValue: 0);
var uOld = [Double](count: CELL_COUNT, repeatedValue: 0);
var v = [Double](count: CELL_COUNT, repeatedValue: 0);
var vOld = [Double](count: CELL_COUNT, repeatedValue: 0);
var curl = [Double](count: CELL_COUNT, repeatedValue: 0);

func fluidDynamicsStep() -> [Double]
{
    for i in 45 ..< 55
    {
        for j in 90 ..< 100
        {
            d[getIndex(i, j)] = 1;
        }
    }
    
    velocitySolver();
    densitySolver();
    
    return d;
}

func densitySolver()
{
    d = addSource(d, dOld);

    swapD();
    d = diffuse(0, d, dOld, diff);
    swapD();
    
    d = advect(0, d, dOld, u, v, clipValue: false);
    
    dOld = [Double](count: CELL_COUNT, repeatedValue: 0);
}

func velocitySolver()
{
    u = addSource(u, uOld);
    v = addSource(v, vOld);
    
    vorticityConfinement();
    
    u = addSource(u, uOld);
    v = addSource(v, vOld);
    
    buoyancy();
    
    v = addSource(v, vOld);
    
    swapU();
    u = diffuse(0, u, uOld, visc);
    
    swapV();
    v = diffuse(0, v, vOld, visc);
    
    project();
    
    swapU();
    swapV();
    
    u = advect(1, u, uOld, uOld, vOld);
    v = advect(2, v, vOld, uOld, vOld);
    
    // make an incompressible field
    project()
    
    uOld = [Double](count: CELL_COUNT, repeatedValue: 0);
    vOld = [Double](count: CELL_COUNT, repeatedValue: 0);
}

func advect (b:Int, unused:[Double], d0:[Double], du:[Double], dv:[Double], clipValue : Bool = false) -> [Double]
{
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    let dt0 = dt * Double(GRID_HEIGHT);
    
    let dt0x = dt * Double(GRID_HEIGHT);
    let dt0y = dt * Double(GRID_HEIGHT);

    for var i = GRID_HEIGHT; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            let index = getIndex(i, j);
            var x = Double(i) - dt0x * du[index];
            var y = Double(j) - dt0y * dv[index];
            
            if (x > Double(GRID_HEIGHT) + 0.5)
            {
                x = Double(GRID_HEIGHT) + 0.5;
            }
            if (x < 0.5)
            {
                x = 0.5;
            }
   
            if (y > Double(GRID_HEIGHT) + 0.5)
            {
                y = Double(GRID_HEIGHT) + 0.5;
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
            
            var cellValue = s0 * (t0 * d0[getIndex(i0, j0)] + t1 * d0[getIndex(i0, j1)]) + s1 * (t0 * d0[getIndex(i1, j0)] + t1 * d0[getIndex(i1, j1)]);
            
            if clipValue
            {
                if cellValue < 0
                {
                    cellValue = 0;
                }
                else if cellValue > 1
                {
                    cellValue = 1;
                }
            }

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
            div[getIndex(i, j)] = (u[getIndex(i+1, j)] - u[getIndex(i-1, j)] + v[getIndex(i, j+1)] - v[getIndex(i, j-1)]) * -0.5 / Double(GRID_HEIGHT);
            
            p[getIndex(i, j)] = Double(0.0);
        }
        
    }
    
    div = setBoundry(0, div);
    p = setBoundry(0, p);
    
    p = linearSolver(0, p, div, 1, 4);
    
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            u[getIndex(i, j)] -= 0.5 * Double(GRID_HEIGHT) * (p[getIndex(i+1, j)] - p[getIndex(i-1, j)]);
            v[getIndex(i, j)] -= 0.5 * Double(GRID_HEIGHT) * (p[getIndex(i, j+1)] - p[getIndex(i, j-1)]);
        }
    }
    
    u = setBoundry(1, u);
    v = setBoundry(2, v);
}

func linearSolver(b:Int, x:[Double], x0:[Double], a:Double, c:Double) -> [Double]
{
    let linearSolverIterations = 2;
    var returnArray = [Double](count: CELL_COUNT, repeatedValue: 0.0)
    
    for var k = 0; k < linearSolverIterations ; k++
    {
        for var i = GRID_WIDTH; i >= 1; i--
        {
            for var j = GRID_HEIGHT; j >= 1; j--
            {
                returnArray[getIndex(i, j)] = (a * ( x[getIndex(i-1, j)] + x[getIndex(i+1, j)] + x[getIndex(i, j-1)] + x[getIndex(i, j+1)]) + x0[getIndex(i, j)]) / c;
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
            vOld[getIndex(i, j)] = a * d[getIndex(i, j)] + -b * (d[getIndex(i, j)] - Tamb);
        }
    }
}

// always on vorticityConfinement(uOld, vOld);
func vorticityConfinement()
{
    var dw_dx:Double;
    var dw_dy:Double;
    var length:Double;
    var v:Double;

    
    // Calculate magnitude of curlf(u,v) for each cell. (|w|)
    var  tt:Double;
    
    for var i = GRID_WIDTH; i >= 1; i--
    {
        for var j = GRID_HEIGHT; j >= 1; j--
        {
            tt=curlf(i, j)
            curl[getIndex(i, j)] = tt<0 ? tt * -1:tt;
        }
    }
    
    for var i = 2; i < GRID_WIDTH; i++
    {
        for var j = 2; j < GRID_HEIGHT; j++
        {
            
            // Find derivative of the magnitude (n = del |w|)
            dw_dx = (curl[getIndex(i + 1, j)] - curl[getIndex(i - 1, j)]) * 0.5;
            dw_dy = (curl[getIndex(i, j + 1)] - curl[getIndex(i, j - 1)]) * 0.5;
            
            // Calculate vector length. (|n|)
            // Add small factor to prevent divide by zeros.
            length = sqrt(dw_dx * dw_dx + dw_dy * dw_dy) + 0.000001;
            
            // N = ( n/|n| )
            dw_dx /= length;
            dw_dy /= length;
            
            v = curlf(i, j);
            
            // N x w
            uOld[getIndex(i, j)] = dw_dy * -v;
            vOld[getIndex(i, j)] = dw_dx *  v;
        }
    }
}

func curlf(i:Int, j:Int) -> Double
{
    var du_dy:Double = (u[getIndex(i, j + 1)] - u[getIndex(i, j - 1)]) * 0.5;
    var dv_dx:Double = (v[getIndex(i + 1, j)] - v[getIndex(i - 1, j)]) * 0.5;
    
    return du_dy - dv_dx;
}

func setBoundry(b:Int, x:[Double]) -> [Double]
{
    var returnArray = x;
    
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