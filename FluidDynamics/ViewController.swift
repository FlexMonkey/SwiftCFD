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

