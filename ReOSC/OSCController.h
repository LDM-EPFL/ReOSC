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
    
    BOOL isRecording;
    BOOL isSendingOSC;
    BOOL isPlaying;
    NSTimeInterval customSleep;
    
    OSCManager *myOSCmanagerObject;
    NSMutableArray *myOSCOutputs;
    OSCInPort  *inPort;
    
    double frameTimer;
    double frameTimerIncrement;
    NSString* recordingPath;
    NSTimer* mainTimer;
    NSTimer* playbackTimer;
    NSDateFormatter *timestamp_df;
    NSDateFormatter *duration_df;
    BOOL didJustPause;
    BOOL didJustUnpause;
    NSTimeInterval overallPauseTime;
    NSTimeInterval thisPauseTime;
    NSDate *pauseBegan;

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


//@property (weak) IBOutlet NSButton *cancelButton;
//@property (weak) IBOutlet NSProgressIndicator *dropLoadProgress;
@end
