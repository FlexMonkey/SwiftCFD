//
//  FluidDynamicsSolver.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 26/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import Foundation

let n : Int = 50;
let viscocity : Double = 0.2;
let diffusionRate : Double = 0.01;
let dt : Double = 1;

func step(fluidDynamicsCells : [FluidDynamicsCell])
{
    // velocitySolver();
    // densitySolver();
    
    for var i = 1; i < n - 1; i++
    {
        var sourceCell = fluidDynamicsCells[i]
        var targetCell = FluidDynamicsCell()
        
        targetCell.curl = curlMagnitude(i, fluidDynamicsCells);
        
        targetCell.setUV( vorticityConfinement(i, fluidDynamicsCells) );
        
        targetCell.v = buoyancy(sourceCell);
        
        targetCell.setUV(diffuseWithViscocity(i, fluidDynamicsCells));
    }
}

func diffuseWithViscocity(index : Int, cells : [FluidDynamicsCell]) -> (Double, Double)
{
    let c : Double = (dt * viscocity * Double(n * n));
    
    return linearSolver(index, cells, viscocity, c)
}

func diffuseWithDiffusionRate(index : Int, cells : [FluidDynamicsCell]) -> (Double, Double)
{
    let c : Double = (dt * diffusionRate * Double(n * n));
    
    return linearSolver(index, cells, diffusionRate, c)
}

func linearSolver(index : Int, cells : [FluidDynamicsCell], a : Double, c : Double) -> (Double, Double)
{
    //  x[I(i, j)] = (a * ( x[I(i-1, j)] + x[I(i+1, j)] + x[I(i, j-1)] + x[I(i, j+1)]) + x0[I(i, j)]) / c;
    
    let u = 123.456;
    let v = 987.765
    
    return (u, v); 
}

func buoyancy(cell : FluidDynamicsCell) -> Double
{
    let ambientTemperature = 0.5;
    let a = -0.000056;
    let b = -0.005;
    
    return a * cell.density + -b * (cell.density - ambientTemperature);
}

func curlMagnitude(index : Int, cells : [FluidDynamicsCell]) -> Double
{
    let tt=curlf(index, cells)
    return tt < 0 ? tt * -1 : tt;
}

func vorticityConfinement(index : Int, cells : [FluidDynamicsCell]) -> (Double, Double)
{
    let dw_dx = (cells[index + 1].curl + cells[index - 1].curl) * 0.5;
    let dw_dy = (cells[index + n].curl + cells[index - n].curl) * 0.5;
    let length = hypot(dw_dx, dw_dy);
    
    let v = curlf(index, cells);
    
    return ((dw_dy / length) * -v, (dw_dx / length) * v);
}

func curlf(index : Int, cells : [FluidDynamicsCell]) -> Double
{
    let du_dy = (cells[index + n].u - cells[index - n].u) * 0.5;
    let dv_dx = (cells[index + 1].v - cells[index - 1].v) * 0.5;
    
    return du_dy - dv_dx;
}

/*
func velocitySolver()
{
    vorticityConfinement()  // u and v
    
    buoyancy() // v only
    
    diffuse() // u and v -> linearSolver()
    
    project() // u and v -> linearSolver()
    
    advect(1) // u and v
        project() // u and v -> linearSolver()
}

func densitySolver()
{
    diffuse() // d -> linearSolver()
    
    advect(0) // d
}
*/

