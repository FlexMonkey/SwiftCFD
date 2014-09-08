//
//  ViewController.swift
//  FluidDynamics
//
//  Created by Simon Gladman on 26/08/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var densities : [Double] = [Double](count: CELL_COUNT, repeatedValue: 0);
    
    @IBOutlet var uiImageView: UIImageView!
    var uiImage : UIImage?;
    
    required init(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder);
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        dispatchSolve();
    }

    @IBAction func buttonClick(sender: AnyObject)
    {
        FluidDynamicsSolver_v2.frameNumber = 0;
    }
    
    var previousTouchX : Int?;
    var previousTouchY : Int?;
    
    override func touchesMoved(touches: NSSet, withEvent event: UIEvent)
    {
        let touch = event.allTouches()?.anyObject()?.locationInView(uiImageView)
     
        if let touchX = touch?.x
        {
            if let touchY = touch?.y
            {
                let scaledX = touchX / 3
                let scaledY = touchY / 3

                
                for var i = scaledX - 3; i < scaledX + 3; i++
                {
                    for var j = scaledY - 3; j < scaledY + 3; j++
                    {
                        let targetIndex = ViewController.getIndex(Int(i), j: Int(j));
                        
                        if targetIndex > 0 && targetIndex < CELL_COUNT
                        {
                            FluidDynamicsSolver_v2.d[targetIndex] = 0.9;
                            
                            if let ptx = previousTouchX
                            {
                                if let pty = previousTouchY
                                {
                                    FluidDynamicsSolver_v2.u[targetIndex] = FluidDynamicsSolver_v2.u[targetIndex] + Double((Int(scaledX) - ptx))
                                    FluidDynamicsSolver_v2.v[targetIndex] = FluidDynamicsSolver_v2.v[targetIndex] + Double((Int(scaledY) - pty))
                                }
                            }
                        }
                    }
                }
                previousTouchX = Int(scaledX);
                previousTouchY = Int(scaledY);
            }
        }
    }
    
    override func touchesEnded(touches: NSSet, withEvent event: UIEvent)
    {
        previousTouchX = nil;
        previousTouchY = nil;
    }
    
    func dispatchSolve()
    {
        Async.background
        {
            self.densities = FluidDynamicsSolver_v2.fluidDynamicsStep()
        }
        .main
        {
            self.dispatchRender();
          
            self.dispatchSolve();
        }
    }
    
    func dispatchRender()
    {
        Async.background
            {
                self.uiImage = renderFluidDynamics(self.densities);
            }
            .main
            {
                self.uiImageView.image = self.uiImage;
        }
    }

    class func getIndex(i : Int, j : Int) -> Int
    {
        return i + 1 + (GRID_WIDTH + 2) * (j + 1);
    }
    
}

