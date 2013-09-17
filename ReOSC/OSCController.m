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
    myOSCmanagerObject = [[OSCManager alloc] init];
    [myOSCmanagerObject setDelegate:self];
    myOSCOutputs=[[NSMutableArray alloc] init];
    isSendingOSC=NO;
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
    //[timestamp_df setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    
    duration_df = [[NSDateFormatter alloc] init];
    [duration_df setDateFormat:@"HH:mm:ss.SS"];
    [duration_df setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    
    mainTimer = [NSTimer scheduledTimerWithTimeInterval:1/60 target:self selector:@selector(updateLoop) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:mainTimer forMode:NSDefaultRunLoopMode];
    
 
}

// Loop
-(void)updateLoop{
    [self setupOSCInput];
    [self setupOSCOutput];
    [self flushRecordBuffer];
    //[self playbackRecording];
    [NSThread sleepUntilDate: [[NSDate date] addTimeInterval: .01]];
}

// Play button clicked
- (IBAction)playButton:(id)sender {
    
    
    // Playback ON
    if([sender state] == NSOnState){

        [self playback_on];
    
        
    // Playback OFF
    }else{
        [self playback_off];
    }

}

-(void)playback_on{
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"b_play"];
    
    // Turn off listen and record
    [[AppCommon sharedAppCommon] setStatusLight_playback:[NSColor greenColor]];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_record"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_listen"];
    
    playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1/30 target:self selector:@selector(playbackFrame) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:playbackTimer forMode:NSDefaultRunLoopMode];
    
    logDatePointer=nil;
    didJustPause=TRUE;
    didJustUnpause=FALSE;
    overallPauseTime=0;


}
-(void)playback_off{
    [[AppCommon sharedAppCommon] setStatusLight_playback:[NSColor orangeColor]];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
    [[AppCommon sharedAppCommon] setPlaybackDuration:0];
    [playbackTimer invalidate];
    
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
    logPointer=0;
    logBegins=nil;
    playbackBegan=nil;
    
    
    // Set playback duration
    [[AppCommon sharedAppCommon] setPlaybackDuration:0];

 
}

// Record button clicked
- (IBAction)recordButton:(id)sender{

    // Recording ON
    if([sender state] == NSOnState){
        
        if(![[NSUserDefaults standardUserDefaults] boolForKey:@"b_listen"]){
            [sender setState:NSOffState];
            [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_record"];
            
            [AppDelegate alertUser:@"Nothing to record!" info:@"Turn on listening first."];
        }else{
        
        //NSLog(@"Recording on...");
        
        // Base path where recordings live
        recordingPath=nil;
        NSString* basePath = [[NSUserDefaults standardUserDefaults] valueForKey:@"recordingBasepath"];

        // If recording path is blank, set default
        if([basePath length] == 0){
            basePath = [NSString stringWithFormat:@"%@/Desktop/%@",NSHomeDirectory(),[[NSProcessInfo processInfo] processName]];
        }
        
        [[NSUserDefaults standardUserDefaults] setValue:basePath forKey:@"recordingBasepath"];
        
        // Check to see if directory exists
        NSFileManager *fileManager= [NSFileManager defaultManager];
        BOOL isDirectory;
        if(![fileManager fileExistsAtPath:basePath isDirectory:&isDirectory]){
            [sender setState:NSOffState];
            [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_record"];
             [AppDelegate alertUser:@"Cannot Record!" info:[NSString stringWithFormat:@"Destination directory does not exist:\n%@",basePath]];
            return;
        }
            
            
       
                [[AppCommon sharedAppCommon] setStatusLight_recording:[NSColor redColor]];
         }
    
    // Recording OFF
    }else{
        [[AppCommon sharedAppCommon] setStatusLight_recording:[NSColor grayColor]];
        //NSLog(@"Recording off...");
        
        
        

        //NSLog(@"OUT: %@,",[NSString stringWithFormat:@"%.25f",timeStamp]);
        if([recordBuffer count] == 0){
            [AppDelegate alertUser:@"Not saving" info:@"No data was received, there's nothing to save!"];
        }

        [self flushRecordBufferForce:YES openOnCompletion:YES];
        [recordBuffer removeAllObjects];
        
    }
}


-(void)playbackFrame{
    
    if([[AppCommon sharedAppCommon] playbackAvailable]){
        // Play


        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_play"]){
            
            
            
            // If paused
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_pause"]){
                [[AppCommon sharedAppCommon] setStatusLight_playback:[NSColor orangeColor]];
                
                if(didJustPause){
                    pauseBegan=[NSDate date];
                    didJustPause=FALSE;
                    thisPauseTime=0;
                }
                thisPauseTime=[[NSDate date] timeIntervalSinceDate:pauseBegan];
                didJustUnpause=TRUE;
                
            // Playback...
            }else{
                didJustPause=TRUE;
                
                if(didJustUnpause){
                    
                    overallPauseTime=overallPauseTime+thisPauseTime;
                    didJustUnpause=FALSE;
                }
                [[AppCommon sharedAppCommon] setStatusLight_playback:[NSColor greenColor]];
                
            
                // Out of range
                if (logPointer >= [[[AppCommon sharedAppCommon] input_oscFromLog] count] ) {
                    [self playback_off];
                    
                    // Are we looping?
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_loopPlayback"]){
                        [self playback_on];
                    }
                    return;
                }
        
                // Grab the entry from the log
                NSDate *now = [NSDate date];
                NSArray *logEntry = [[AppCommon sharedAppCommon] input_oscFromLog][logPointer];
                NSDate *logEntryTimeStamp = [NSDate dateWithTimeIntervalSince1970:[logEntry[0] doubleValue]];
                
                // If this is the first time through
                if(!logBegins){
                    logBegins=logEntryTimeStamp;
                    lastVisitedLog = now;
                    playbackBegan=now;
                }

                // Overall time and when event should occur
                NSTimeInterval overallTimeElapsed=[now timeIntervalSinceDate:playbackBegan]-overallPauseTime;
                NSTimeInterval timeEventShouldOccurAt=[logEntryTimeStamp timeIntervalSinceDate:logBegins];

                if (overallTimeElapsed >= timeEventShouldOccurAt){
                    [self sendLogEntry:logEntry];
                    logPointer++;
                }
                
                // Set playback duration
                [[AppCommon sharedAppCommon] setPlaybackDuration:[self stringFromTimeInterval:overallTimeElapsed]];

            }
        }
    }
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    return [NSString stringWithFormat:@"%02li:%02li:%02li", (long)hours, (long)minutes, (long)seconds];
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
    if (isSendingOSC){
        for(OSCOutPort *oscOut in myOSCOutputs){
            [oscOut sendThisMessage:newMessage];
        }
    }
}

// Flush the buffer to disk (threaded so we don't slow down logging)
-(void)flushRecordBuffer{
    [self flushRecordBufferForce:NO openOnCompletion:NO];
}

-(void)flushRecordBufferForce:(BOOL)force openOnCompletion:(bool)shouldOpen{
        
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
            //NSLog(@"Recording to: %@",recordingPath);
        }
        
        
        // Make deep copy
        NSMutableArray *bufferCopy = [[NSMutableArray alloc] initWithArray:recordBuffer copyItems:YES];
        
        // Wipe out the old one so we can keep logging
        [recordBuffer removeAllObjects];
        
        // Write to disk (threaded with copy so we don't delay)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            
            // For every message in the buffer, dump it
            NSMutableArray *humanReadableArray=[[NSMutableArray alloc] init];
            
            for(NSArray* logLine in bufferCopy){
                NSString* timeStamp = logLine[0];
                OSCMessage *m = logLine[1];
                NSString* oscPacketLogLine= [NSString stringWithFormat:@"%@: %@",timeStamp,[m address]];
                
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
            
            
            // Callback
            dispatch_async(dispatch_get_main_queue(), ^{
                if(shouldOpen){
                    [[AppCommon sharedAppCommon] loadLogFileFromPath:[NSArray arrayWithObject:recordingPath]];
                }
            });

        });
    }
}


// Reset OSC (clear all listeners and senders)
-(void)resetOSC{
    [myOSCmanagerObject deleteAllInputs];
    [myOSCmanagerObject deleteAllOutputs];
    [myOSCOutputs removeAllObjects];
}

// Set up the OSC Listener as needed
-(void)setupOSCInput{
     if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_listen"]){
        [myOSCmanagerObject deleteAllInputs];
         inPort=nil;
        [[AppCommon sharedAppCommon] setValue:[NSColor grayColor] forKey:@"statusLight"];
     }else{
         
         
         // What if user sends blank port?
         if([[[NSUserDefaults standardUserDefaults] valueForKey:@"osc_listenPort"] length] == 0){
             [AppDelegate alertUser:@"Listening port cannot be blank" info:@"Provide a port to listen"];
             [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_listen"];
             return;
         }
         
         // Turn on the listening light
         [[AppCommon sharedAppCommon] setValue:[NSColor orangeColor] forKey:@"statusLight"];
         if(!inPort){
             int listenPort=(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"osc_listenPort"];
             //NSLog(@"OSC: Bind to port: %i",listenPort);
             [myOSCmanagerObject deleteAllInputs];
             inPort = [myOSCmanagerObject createNewInputForPort:listenPort];
                 
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
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_send"]){
        [myOSCmanagerObject deleteAllOutputs];
        isSendingOSC=NO;
    }else{
        
        // Setup once
        if(!isSendingOSC){
            NSString* listOfDestinations = [[NSUserDefaults standardUserDefaults] valueForKey:@"osc_sendList"];
            [[NSUserDefaults standardUserDefaults] setValue:[listOfDestinations stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"osc_sendList"];
            
            
            NSArray* arrayOfInputs = [listOfDestinations componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
            NSString* addressMessage = @"You should provide at least one outgoing address in the format IP:PORT (IE: 127.0.0.1:8888)\n\nYou may provide more than one address, use commas or spaces to separate them.";
            
            // No output specified
            if([listOfDestinations length] == 0){
                [AppDelegate alertUser:@"No address to send to!" info:addressMessage];
                [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_send"];
                return;
            }
            
            for(NSString* possibleAddress in arrayOfInputs){
                NSString* possibleAddressTrimmed = [possibleAddress stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                if([possibleAddressTrimmed length]>0){

                    
                   // NSLog(@"-%@-",possibleAddressTrimmed);
                    NSArray* outputAddress = [possibleAddressTrimmed componentsSeparatedByString:@":"];

                    if([outputAddress count] < 2){
                        [AppDelegate alertUser:@"Malformed Address" info:[NSString stringWithFormat:@"I don't know how to send to %@\n\n%@",possibleAddress,addressMessage]];
                        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_send"];
                    }else{
                        NSString* oscIP = outputAddress[0];
                        double oscPort = [outputAddress[1] doubleValue];
                        OSCOutPort *newOSCOutput = [myOSCmanagerObject createNewOutputToAddress:oscIP atPort:oscPort];
                        [myOSCOutputs addObject:newOSCOutput];
                    }
                }
            }
        }
        
       isSendingOSC=YES;
    }
}


// Incoming OSC message callback
- (void) receivedOSCMessage:(OSCMessage *)m	{
	[[AppCommon sharedAppCommon] setValue:[NSColor greenColor] forKey:@"statusLight"];
    
    // If we are repeating, repeat
    if (isSendingOSC){
        for(OSCOutPort *oscOut in myOSCOutputs){
            [oscOut sendThisMessage:m];
        }
    }
	
    
    // If record option is on, add message to buffer
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"b_record"]){
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        NSMutableArray *logEntry=[[NSMutableArray alloc] init];
        [logEntry addObject:[NSString stringWithFormat:@"%f",timeStamp]];
        [logEntry addObject:m];
        [recordBuffer addObject:logEntry];
    }
}




@end
