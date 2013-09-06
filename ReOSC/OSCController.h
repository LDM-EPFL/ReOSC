//
//  OSCController.h
//  ReduOSC
//
//  Created by Andrew on 9/5/13.
//  Copyright (c) 2013 FERAL RESEARCH COALITION. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class OSCManager;
@class OSCOutPort;
@class OSCInPort;

@interface OSCController : NSView{
    OSCManager *OSCmanagerObject;
    OSCOutPort *OSCOutput;
    OSCInPort					*inPort;
    NSString* recordingPath;
    
    NSTimer* mainTimer;
    
    NSMutableArray* recordBuffer;
    int flushBufferAt;
}

@end
