//
//  OSCController.h
//  ReOSC
//
//  Created by Andrew on 9/5/13.
//  Copyright (c) 2013 FERAL RESEARCH COALITION. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class OSCManager;
@class OSCOutPort;
@class OSCInPort;

@interface OSCController : NSView{
    
    BOOL isSendingOSC;
    OSCManager *OSCmanagerObject;
    NSMutableArray *OSCOutputs;
    OSCInPort  *inPort;
    
    double frameTimer;
    double frameTimerIncrement;
    NSString* recordingPath;
    NSTimer* mainTimer;
    NSTimer* playbackTimer;
    NSDateFormatter *timestamp_df;

    NSDate* next_timeStampAsDateObject;
    NSDate* logDatePointer;
    NSDate* lastVisitedLog;
    NSDate* logBegins;
    NSDate* playbackBegan;
    bool waitMessage;
    
    BOOL f_playbackRecording;
    int logPointer;
    NSMutableArray* recordBuffer;
    int flushBufferAt;
}


@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSProgressIndicator *dropLoadProgress;
@end
