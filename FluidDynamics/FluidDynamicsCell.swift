//
//  FluidDynamicsCell.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 27/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import Foundation

struct FluidDynamicsCell
{
    var density : Double = 0.01;
    var u : Double = 0;
    var v : Double = 0;
    var curl : Double = 0;
    
    mutating func setUV(value:(u : Double, v : Double))
    {
        self.u = value.u;
        self.v = value.v;
    }
    
    mutating func addUV(value:(u : Double, v : Double))
    {
        self.u = self.u + value.u;
        self.v = self.v + value.v;
    }
}