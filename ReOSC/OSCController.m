//
//  OSCController.m
//  ReOSC
//
//  Created by Andrew on 9/5/13.
//  Copyright (c) 2013 FERAL RESEARCH COALITION. All rights reserved.
//
// Fixes NSLOG (removes timestamp)
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

#import "OSCController.h"
#import <VVOSC/VVOSC.h>
#import "AppDelegate.h"
#import "AppCommon.h"


#define fequal(a,b) (fabs((a) - (b)) < DBL_EPSILON)
#define fequalzero(a) (fabs(a) < DBL_EPSILON)

@implementation OSCController


// Initial setup
- (void)awakeFromNib{
    
    // Allocate OSC devices
    OSCmanagerObject = [[OSCManager alloc] init];
    [OSCmanagerObject setDelegate:self];
    [self resetOSC];
    
    // Allocate a recording buffer
    recordBuffer = [[NSMutableArray alloc] init];
    // Number of entries before we dump record buffer to disk
    flushBufferAt = 1000;
    
    // Startup state
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_record"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_loopPlayback"];
    [[AppCommon sharedAppCommon] setShowLoadProgress:FALSE];

    
    timestamp_df = [[NSDateFormatter alloc] init];
    [timestamp_df setDateFormat:@"MMM dd HH:mm:ssssss.SSS"];
    
    mainTimer = [NSTimer scheduledTimerWithTimeInterval:1/10 target:self selector:@selector(updateLoop) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:mainTimer forMode:NSEventTrackingRunLoopMode];
    
}

// Loop
-(void)updateLoop{
    [self setupOSCInput];
    [self setupOSCOutput];
    [self flushRecordBuffer];
    //[self playbackRecording];
}

// Play button clicked
- (IBAction)playButton:(id)sender {
    
    
    // Playback ON
    if([sender state] == NSOnState){

        // Turn off listen and record
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_record"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_listen"];
        
        playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1/30 target:self selector:@selector(playbackFrame) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:playbackTimer forMode:NSEventTrackingRunLoopMode];
        
        logDatePointer=nil;

        
    // Playback OFF
    }else{
        [playbackTimer invalidate];
    }

}

// Record button clicked
- (IBAction)recordButton:(id)sender{

    // Recording ON
    if([sender state] == NSOnState){
        NSLog(@"Recording on...");
        
        // Base path where recordings live
        recordingPath=nil;
        NSString* basePath = [[NSUserDefaults standardUserDefaults] valueForKey:@"recordingBasepath"];

        // If recording path is blank, set default
        if([basePath length] == 0){
            basePath = [NSString stringWithFormat:@"%@/Desktop/%@",NSHomeDirectory(),[[NSProcessInfo processInfo] processName]];
        }
        
        [[NSUserDefaults standardUserDefaults] setValue:basePath forKey:@"recordingBasepath"];
        
        // Init directory so it's present
        
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        NSLog(@"IN: %@,",[NSString stringWithFormat:@"%.25f",timeStamp]);
    
    // Recording OFF
    }else{
        NSLog(@"Recording off...");
        if([recordBuffer count] == 0){
            [AppDelegate alertUser:@"Nothing to log" info:@"Not saving anything because no data was recieved!"];
        }
        
        [self flushRecordBuffer:YES];
        [recordBuffer removeAllObjects];
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        NSLog(@"OUT: %@,",[NSString stringWithFormat:@"%.25f",timeStamp]);

        
    }
}


-(void)playbackFrame{
    
    if([[AppCommon sharedAppCommon] playbackAvailable]){
        // Play
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_play"]){
            // If not paused
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_pause"]){
                
                
            
                // Out of range
                if (logPointer >= [[[AppCommon sharedAppCommon] input_oscFromLog] count] ) {
                    
                    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
                    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
                    logPointer=0;
                    logBegins=nil;
                    playbackBegan=nil;
                    
                    // Are we looping?
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_loopPlayback"]){
                        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"b_play"];
                    }
                    return;
                }
        

                NSArray *logEntry = [[AppCommon sharedAppCommon] input_oscFromLog][logPointer];
                NSDate *now = [NSDate date];
                NSDate *logEntryTimeStamp = [NSDate dateWithTimeIntervalSince1970:[logEntry[0] doubleValue]];
                
                // First entry in the log
                if(!logBegins){
                    logBegins=logEntryTimeStamp;
                    lastVisitedLog = now;
                    playbackBegan=now;
                }

                // Overall time and when event should occur
                NSTimeInterval overallTimeElapsed=[now timeIntervalSinceDate:playbackBegan];
                NSTimeInterval timeEventShouldOccurAt=[logEntryTimeStamp timeIntervalSinceDate:logBegins];

                if (overallTimeElapsed >= timeEventShouldOccurAt){
                    [self sendLogEntry:logEntry];
                    logPointer++;
                }


            }
        }
    }
}


-(void)playbackFrame1{
    NSArray* logEntry = [[AppCommon sharedAppCommon] input_oscFromLog][logPointer];
    next_timeStampAsDateObject = [NSDate dateWithTimeIntervalSince1970:[logEntry[0] doubleValue]];
    [self sendLogEntry:logEntry];
    logPointer++;
    
    
    // Out of range
    if (logPointer >= [[[AppCommon sharedAppCommon] input_oscFromLog] count] ) {
        
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
        logPointer=0;
        
        // Are we looping?
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_loopPlayback"]){
            [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"b_play"];
        }
    }


}

-(void)playbackFrame2{
    
    if([[AppCommon sharedAppCommon] playbackAvailable]){
        // Play
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_play"]){
            // If not paused
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_pause"]){
                
                // Right now?
                NSDate *now = [NSDate date];
                
                // Set our "date pointer" to the first entry in the log
                if(!logDatePointer){
                    // Get a timestamp
                    NSLog(@"First time...");
                    NSTimeInterval timeStamp =[[[AppCommon sharedAppCommon] input_oscFromLog][logPointer][0] doubleValue];
                    NSDate *timeStampAsDateObject = [NSDate dateWithTimeIntervalSince1970:timeStamp];
                    next_timeStampAsDateObject=timeStampAsDateObject;
                    logDatePointer = timeStampAsDateObject;
                    lastVisitedLog = now;
                    logBegins=timeStampAsDateObject;
                }
                
                // We should be at t+time since we last checked
                NSTimeInterval timeSinceLastVisit=[now timeIntervalSinceDate:lastVisitedLog];
                logDatePointer=[logDatePointer dateByAddingTimeInterval:timeSinceLastVisit];
                
                NSLog(@"%@",[timestamp_df stringFromDate:now]);
                NSLog(@">>%@",[timestamp_df stringFromDate:logDatePointer]);
                
                // If there are events in the log corresponding to this time chunk, pump them out
                int eventsThisChunk=0;
                while(  ([logDatePointer compare:next_timeStampAsDateObject] == NSOrderedDescending)
                      ||([logDatePointer compare:next_timeStampAsDateObject] == NSOrderedSame)){
                    
                    // Out of range
                    if (logPointer >= [[[AppCommon sharedAppCommon] input_oscFromLog] count] ) {
                        
                        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
                        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
                        logPointer=0;
                        logDatePointer=nil;
                        
                        // Are we looping?
                        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_loopPlayback"]){
                            [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"b_play"];
                        }
                        
                        break;
                    }
                    
                    NSArray* logEntry = [[AppCommon sharedAppCommon] input_oscFromLog][logPointer];
                    //NSLog(@"%@ is >= %@",[timestamp_df stringFromDate:next_timeStampAsDateObject],[timestamp_df stringFromDate:logDatePointer]);
                    next_timeStampAsDateObject = [NSDate dateWithTimeIntervalSince1970:[logEntry[0] doubleValue]];
                    [self sendLogEntry:logEntry];
                    logPointer++;
                    
                    eventsThisChunk++;
                    
                }
                if(eventsThisChunk > 0){
                //NSLog(@"Finished checked: %.10f ago (processed %d/%ld events) pointer:%i\n\n",timeSinceLastVisit,eventsThisChunk,(unsigned long)[[[AppCommon sharedAppCommon] input_oscFromLog] count],logPointer);
                }
                lastVisitedLog=now;
                
            }
        }
    }
}


-(void)sendLogEntry:(NSArray *)logEntry{

    NSString* oscAddress=logEntry[1];
    OSCMessage* newMessage;
    
    // Revenge of TSPS (they send their messages weirdly, but not all of them)
    if([oscAddress isEqualToString:@"/TSPS/personUpdated"] ||
       [oscAddress isEqualToString:@"/TSPS/personWillLeave"] ||
       [oscAddress isEqualToString:@"/TSPS/personEntered"]){
        newMessage = [OSCMessage createQueryType:OSCQueryTypeNamespaceExploration forAddress:oscAddress];
        
    }else{
        newMessage = [OSCMessage createWithAddress:oscAddress];
    }
    
    
    int counter=0;
    for(NSString* messageComponant in logEntry){
        if(counter > 1){
            
            NSString* oscMessageType=[messageComponant componentsSeparatedByString:@":"][0];
            NSString* oscMessageContent=[messageComponant componentsSeparatedByString:@":"][1];
            
            // Float
            if([oscMessageType isEqualToString:@"f"]){
                [newMessage addFloat:[oscMessageContent floatValue]];
                
                // Integer
            }else if([oscMessageType isEqualToString:@"i"]){
                [newMessage addInt:(int)[oscMessageContent integerValue]];
                
                // Stringf
            }else if([oscMessageType isEqualToString:@"s"]){
                [newMessage addString:oscMessageContent];
            }
        }
        counter++;
    }
   
    // Actually send
    if(OSCOutput){
        [OSCOutput sendThisMessage:newMessage];
    }

}

// Flush the buffer to disk (threaded so we don't slow down logging)
-(void)flushRecordBuffer{
    [self flushRecordBuffer:NO];
}

-(void)flushRecordBuffer:(bool)force{
        
    // If we should flush now
    if(force || ([recordBuffer count] > flushBufferAt)){
        
        // Setup a directory if we don't have one
        if(!recordingPath){
            // Make a subfolder under basepath
            // NSTimeInterval is defined as double
            NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
            NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
            NSString *recordPath_withSubdir = [NSString stringWithFormat:@"%@/%@/",[[NSUserDefaults standardUserDefaults] stringForKey:@"recordingBasepath"],timeStampObj];
            [ [ NSFileManager defaultManager ] createDirectoryAtPath: recordPath_withSubdir withIntermediateDirectories: YES attributes: nil error: NULL ];
            
            recordingPath=recordPath_withSubdir;
            NSLog(@"Recording to: %@",recordingPath);
        }
        
        
        // Make deep copy
        NSMutableArray *bufferCopy = [[NSMutableArray alloc] initWithArray:recordBuffer copyItems:YES];
        
        // Wipe out the old one so we can keep logging
        [recordBuffer removeAllObjects];
        
        // Write to disk (threaded with copy so we don't delay)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            
            // For every message in the buffer, dump it
            NSMutableArray *humanReadableArray=[[NSMutableArray alloc] init];
            
            for(OSCMessage *m in bufferCopy){
                NSString* oscPacketLogLine=[[NSString alloc] init];
                NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
                oscPacketLogLine = [NSString stringWithFormat:@"%.25f: %@",timeStamp,[m address]];
                
                for(OSCValue *v in [m valueArray]){
                   
                    // At the moment we don't handle all OSC types, only int, float, string...
                    switch(v.type){
                            
                        case OSCValInt: //!<Integer, -2147483648 to 2147483647
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ i:%i",oscPacketLogLine,v.intValue];
                            break;
                        case OSCValFloat: //!<Float
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ f:%f",oscPacketLogLine,v.floatValue];
                            break;
                        case OSCValString: //!<String
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ s:%@",oscPacketLogLine,v.stringValue];
                            break;
                        /*
                        case OSCValTimeTag://!<TimeTag
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ tt:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCVal64Int:	//!<64-bit integer, -9223372036854775808 to 9223372036854775807
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ i64:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValDouble:	//!<64-bit float (double)
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ d64:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValChar:	//!<Char
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ c:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValColor:	//!<Color
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ color:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValMIDI:	//!<MIDI
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ midi:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValBool:	//!<BOOL
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ b:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValNil:	//!<nil/NULL
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ nil:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValInfinity:	//!<Infinity
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ inf:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                        case OSCValBlob:	//!<Blob- random binary data
                            oscPacketLogLine = [NSString stringWithFormat:@"%@ blob:%@",oscPacketLogLine,[[v value] stringValue]];
                            break;
                         */

                    }
                }
                [humanReadableArray addObject:oscPacketLogLine];
            }
            
           
            // Filenames are UNIXTIME.log
            NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:humanReadableArray];
            NSError *error = nil;
            NSString *recordPath = [NSString stringWithFormat:@"%@/%f.log",recordingPath,timeStamp];
            
            [data writeToFile:recordPath
                      options:NSDataWritingAtomic
                        error:&error];

            if ([error localizedDescription]){
                NSLog(@"ERROR!: Error writing log to disk %@", [error localizedDescription]);
            }

        });
    }
}


// Reset OSC (clear all listeners and senders)
-(void)resetOSC{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [OSCmanagerObject deleteAllInputs];
        [OSCmanagerObject deleteAllOutputs];
    });
}

// Set up the OSC Listener as needed
-(void)setupOSCInput{
     if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_listen"]){
        [OSCmanagerObject deleteAllInputs];
         inPort=nil;
         	[[AppCommon sharedAppCommon] setValue:[NSColor grayColor] forKey:@"statusLight"];
     }else{
         [[AppCommon sharedAppCommon] setValue:[NSColor orangeColor] forKey:@"statusLight"];

         if(!inPort){
             int listenPort=(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"osc_listenPort"];
             NSLog(@"OSC: Bind to port: %i",listenPort);
             [OSCmanagerObject deleteAllInputs];
             inPort = [OSCmanagerObject createNewInputForPort:listenPort];
                 
             if(!inPort){
                [AppDelegate alertUser:@"Error!" info:[NSString stringWithFormat:@"I cannot bind to port %ld. Perhaps it's in use?",(long)[[NSUserDefaults standardUserDefaults] integerForKey:@"osc_listenPort"]]];
                
                 [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_listen"];
             }
         }
    }    
}


// Set up the OSC Sender as needed
-(void)setupOSCOutput{
    
    // Setup output
    if (![[NSUserDefaults standardUserDefaults] integerForKey:@"b_send"]){
        [OSCmanagerObject deleteAllOutputs];
        OSCOutput=nil;
    }else{
        double oscPort = [[NSUserDefaults standardUserDefaults] integerForKey:@"osc_sendPort"];
        NSString *oscIP = [[NSUserDefaults standardUserDefaults] valueForKey:@"osc_sendIP"];
        if (!OSCOutput){
            OSCOutput = [OSCmanagerObject createNewOutputToAddress:oscIP atPort:oscPort];
        }
    }
}


// Incoming OSC message callback
- (void) receivedOSCMessage:(OSCMessage *)m	{
	[[AppCommon sharedAppCommon] setValue:[NSColor greenColor] forKey:@"statusLight"];
    
    // If we are repeating, repeat
	if(OSCOutput){
        [OSCOutput sendThisMessage:m];
    }
    
    // If record option is on, add message to buffer
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"b_record"]){
        [recordBuffer addObject:m];
    }
}




@end
