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
        frameNumber = 0;
    }
    
    var previousTouchX : Int?;
    var previousTouchY : Int?;
    
    override func touchesMoved(touches: NSSet!, withEvent event: UIEvent!)
    {
        let touch = event.allTouches().anyObject().locationInView(uiImageView);
        
        let touchX = Int(touch.x / 3);
        let touchY = Int(touch.y / 3);
   
        for i in touchX - 3 ..< touchX + 3
        {
            for j in touchY - 3 ..< touchY + 3
            {
                let targetIndex = getIndex(i, j);
                
                if targetIndex > 0 && targetIndex < CELL_COUNT
                {
                    d[targetIndex] = 0.9;
                    
                    if let ptx = previousTouchX
                    {
                        if let pty = previousTouchY
                        {
                            u[targetIndex] = u[targetIndex] + Double((touchX - ptx) / 2)
                            v[targetIndex] = v[targetIndex] + Double((touchY - pty) / 2)
                        }
                    }
                }
            }
        }
        
        
        previousTouchX = touchX;
        previousTouchY = touchY;
    }
    
    override func touchesEnded(touches: NSSet!, withEvent event: UIEvent!)
    {
        previousTouchX = nil;
        previousTouchY = nil;
    }
    
    func dispatchSolve()
    {
        Async.background
        {
            self.densities = fluidDynamicsStep()
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

}

