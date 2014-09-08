//
//  AsyncLegacy.swift
//
//  Created by Tobias DM on 15/07/14.
//  Modifed by Joseph Lord
//  Copyright (c) 2014 Human Friendly Ltd.
//
//	OS X 10.9+ and iOS 7.0+
//	Only use with ARC
//
//	The MIT License (MIT)
//	Copyright (c) 2014 Tobias Due Munk
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy of
//	this software and associated documentation files (the "Software"), to deal in
//	the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//	the Software, and to permit persons to whom the Software is furnished to do so,
//	subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import Foundation

// HACK: For Beta 5, 6
prefix func +(v: qos_class_t) -> Int {
	return Int(v.value)
}

private class GCD {
	
	/* dispatch_get_queue() */
	class func mainQueue() -> dispatch_queue_t {
		return dispatch_get_main_queue()
		// Could use return dispatch_get_global_queue(+qos_class_main(), 0)
	}
	class func userInteractiveQueue() -> dispatch_queue_t {
        //return dispatch_get_global_queue(+QOS_CLASS_USER_INTERACTIVE, 0)
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
	}
	class func userInitiatedQueue() -> dispatch_queue_t {
        //return dispatch_get_global_queue(+QOS_CLASS_USER_INITIATED, 0)
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
	}
	class func defaultQueue() -> dispatch_queue_t {
		return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
	}
	class func utilityQueue() -> dispatch_queue_t {
		return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
	}
	class func backgroundQueue() -> dispatch_queue_t {
		return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
	}
}

public class Async {
    
    //The block to be executed does not need to be retained in present code
    //only the dispatch_group is needed in order to cancel it.
    //private let block: dispatch_block_t
    private let dgroup: dispatch_group_t = dispatch_group_create()
    private var isCancelled = false
    private init() {}
    
}


extension Async { // Static methods

	
	/* dispatch_async() */

	private class func async(block: dispatch_block_t, inQueue queue: dispatch_queue_t) -> Async {
        // Wrap block in a struct since dispatch_block_t can't be extended and to give it a group
		let asyncBlock =  Async()

        // Add block to queue
		dispatch_group_async(asyncBlock.dgroup, queue, asyncBlock.cancellable(block))

        return asyncBlock
		
	}
	class func main(block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: GCD.mainQueue())
	}
	class func userInteractive(block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: GCD.userInteractiveQueue())
	}
	class func userInitiated(block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: GCD.userInitiatedQueue())
	}
	class func default_(block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: GCD.defaultQueue())
	}
	class func utility(block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: GCD.utilityQueue())
	}
	class func background(block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: GCD.backgroundQueue())
	}
	class func customQueue(queue: dispatch_queue_t, block: dispatch_block_t) -> Async {
		return Async.async(block, inQueue: queue)
	}


	/* dispatch_after() */

	private class func after(seconds: Double, block: dispatch_block_t, inQueue queue: dispatch_queue_t) -> Async {
		let nanoSeconds = Int64(seconds * Double(NSEC_PER_SEC))
		let time = dispatch_time(DISPATCH_TIME_NOW, nanoSeconds)
		return at(time, block: block, inQueue: queue)
	}
	private class func at(time: dispatch_time_t, block: dispatch_block_t, inQueue queue: dispatch_queue_t) -> Async {
		// See Async.async() for comments
        let asyncBlock = Async()
        dispatch_group_enter(asyncBlock.dgroup)
        dispatch_after(time, queue){
            let cancellableBlock = asyncBlock.cancellable(block)
            cancellableBlock() // Compiler crashed in Beta6 when I just did asyncBlock.cancellable(block)() directly.
            dispatch_group_leave(asyncBlock.dgroup)
        }
		return asyncBlock
	}
	class func main(#after: Double, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: GCD.mainQueue())
	}
	class func userInteractive(#after: Double, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: GCD.userInteractiveQueue())
	}
	class func userInitiated(#after: Double, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: GCD.userInitiatedQueue())
	}
	class func default_(#after: Double, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: GCD.defaultQueue())
	}
	class func utility(#after: Double, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: GCD.utilityQueue())
	}
	class func background(#after: Double, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: GCD.backgroundQueue())
	}
	class func customQueue(#after: Double, queue: dispatch_queue_t, block: dispatch_block_t) -> Async {
		return Async.after(after, block: block, inQueue: queue)
	}
}


extension Async { // Regualar methods matching static once
	
	private func chain(block chainingBlock: dispatch_block_t, runInQueue queue: dispatch_queue_t) -> Async {
		// See Async.async() for comments
        let asyncBlock = Async()
        dispatch_group_enter(asyncBlock.dgroup)
        dispatch_group_notify(self.dgroup, queue) {
            let cancellableChainingBlock = asyncBlock.cancellable(chainingBlock)
            cancellableChainingBlock()
            dispatch_group_leave(asyncBlock.dgroup)
        }
		return asyncBlock
	}
    
    private func cancellable(blockToWrap: dispatch_block_t) -> dispatch_block_t {
        // Retains self in case it is cancelled and then released.
        return {
            if !self.isCancelled {
                blockToWrap()
            }
        }
    }
	
	func main(chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: GCD.mainQueue())
	}
	func userInteractive(chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: GCD.userInteractiveQueue())
	}
	func userInitiated(chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: GCD.userInitiatedQueue())
	}
	func default_(chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: GCD.defaultQueue())
	}
	func utility(chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: GCD.utilityQueue())
	}
	func background(chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: GCD.backgroundQueue())
	}
	func customQueue(queue: dispatch_queue_t, chainingBlock: dispatch_block_t) -> Async {
		return chain(block: chainingBlock, runInQueue: queue)
	}

	
	/* dispatch_after() */

	private func after(seconds: Double, block chainingBlock: dispatch_block_t, runInQueue queue: dispatch_queue_t) -> Async {
        
        var asyncBlock = Async()
        
        dispatch_group_notify(self.dgroup, queue)
        {
            dispatch_group_enter(asyncBlock.dgroup)
            let nanoSeconds = Int64(seconds * Double(NSEC_PER_SEC))
            let time = dispatch_time(DISPATCH_TIME_NOW, nanoSeconds)
            dispatch_after(time, queue) {
                let cancellableChainingBlock = self.cancellable(chainingBlock)
                cancellableChainingBlock()
                dispatch_group_leave(asyncBlock.dgroup)
            }
            
        }

		// Wrap block in a struct since dispatch_block_t can't be extended
		return asyncBlock
	}
	func main(#after: Double, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: GCD.mainQueue())
	}
	func userInteractive(#after: Double, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: GCD.userInteractiveQueue())
	}
	func userInitiated(#after: Double, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: GCD.userInitiatedQueue())
	}
	func default_(#after: Double, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: GCD.defaultQueue())
	}
	func utility(#after: Double, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: GCD.utilityQueue())
	}
	func background(#after: Double, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: GCD.backgroundQueue())
	}
	func customQueue(#after: Double, queue: dispatch_queue_t, block: dispatch_block_t) -> Async {
		return self.after(after, block: block, runInQueue: queue)
	}


	/* cancel */

     func cancel() {
        // I don't think that syncronisation is necessary. Any combination of multiple access
        // should result in some boolean value and the cancel will only cancel
        // if the execution has not yet started.
        isCancelled = true
    }

	/* wait */

	/// If optional parameter forSeconds is not provided, use DISPATCH_TIME_FOREVER
	func wait(seconds: Double = 0.0) {
		if seconds != 0.0 {
			let nanoSeconds = Int64(seconds * Double(NSEC_PER_SEC))
			let time = dispatch_time(DISPATCH_TIME_NOW, nanoSeconds)
            dispatch_group_wait(dgroup, time)
		} else {
			dispatch_group_wait(dgroup, DISPATCH_TIME_FOREVER)
		}
	}
}


// Convenience

// extension qos_class_t {
//
//	// Calculated property
//	var description: String {
//		get {
//			switch +self {
//				case +qos_class_main(): return "Main"
//				case +QOS_CLASS_USER_INTERACTIVE: return "User Interactive"
//				case +QOS_CLASS_USER_INITIATED: return "User Initiated"
//				case +QOS_CLASS_DEFAULT: return "Default"
//				case +QOS_CLASS_UTILITY: return "Utility"
//				case +QOS_CLASS_BACKGROUND: return "Background"
//				case +QOS_CLASS_UNSPECIFIED: return "Unspecified"
//				default: return "Unknown"
//			}
//		}
//	}
//}

