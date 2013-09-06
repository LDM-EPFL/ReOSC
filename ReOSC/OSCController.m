//
//  OSCController.m
//  ReduOSC
//
//  Created by Andrew on 9/5/13.
//  Copyright (c) 2013 FERAL RESEARCH COALITION. All rights reserved.
//

#import "OSCController.h"
#import <VVOSC/VVOSC.h>
#import "AppDelegate.h"
#import "AppCommon.h"

@implementation OSCController


- (void)awakeFromNib{
    
    // Number of entries before we dump record buffer to disk
    flushBufferAt = 10;
    
    OSCmanagerObject = [[OSCManager alloc] init];
    [OSCmanagerObject setDelegate:self];
    [self resetOSC];
    
    mainTimer = [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(updateLoop) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:mainTimer forMode:NSEventTrackingRunLoopMode];

    recordBuffer = [[NSMutableArray alloc] init];


    // Base path where recordings live
    NSString* basePath = [NSString stringWithFormat:@"%@/Desktop/ReduOSC",NSHomeDirectory()];
    [[NSUserDefaults standardUserDefaults] setValue:basePath forKey:@"recordingBasepath"];
    
    [[AppCommon sharedAppCommon] setDropLoadProgress:_dropLoadProgress];
    
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_loopPlayback"];    

}



-(void)updateLoop{
    
    
    [self setupOSCInput];
    
    [self setupOSCOutput];
    
    [self flushRecordBuffer];
    
    [self playbackRecording];
}


-(void)playbackRecording{
    if([[AppCommon sharedAppCommon] playbackAvailable]){
        
        // Play
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_play"]){
            
            // Turn off listen
            [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_listen"];
            [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_record"];
            
            
            // If not paused
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_pause"]){
               
                
                // Get a message
                NSArray* logEntry = [[AppCommon sharedAppCommon] input_oscFromLog][messageCounter];
                
                
                OSCMessage* newMessage = [OSCMessage createWithAddress:logEntry[1]];
                
                int counter=0;
                for(NSString* messageComponant in logEntry){
                    if(counter > 1){
                        
                        NSString* oscMessageType=[messageComponant componentsSeparatedByString:@":"][0];
                        NSString* oscMessageContent=[messageComponant componentsSeparatedByString:@":"][1];
                        
                        // Float
                        if([oscMessageType isEqualToString:@"f"]){
                            [newMessage addFloat:[oscMessageContent floatValue]];
                            
                        // Integer
                        }else  if([oscMessageType isEqualToString:@"i"]){
                            [newMessage addInt:(int)[oscMessageContent integerValue]];
                        
                        // Stringf
                        }else  if([oscMessageType isEqualToString:@"s"]){
                            [newMessage addString:oscMessageContent];

                        
                        }
                        
                    }
                    counter++;
                }
                
                // Actually send by spoofing a recieve from listener
                [self receivedOSCMessage:newMessage];
                
                
                messageCounter++;
                
                // If we are out of range
                if (messageCounter >= [[[AppCommon sharedAppCommon] input_oscFromLog] count] ) {
                    
                   // Are we looping?
                   if ([[NSUserDefaults standardUserDefaults] boolForKey:@"b_loopPlayback"]){
                       messageCounter=0;
                   
                   // Not looping
                   }else{
                       [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_play"];
                       [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"b_pause"];
                       messageCounter=0;
                   }
                }
            }
            
        // Stop
        }else{
            // If stopped, reset counter
            messageCounter=0;
        }
    }
}


// Write all the recorded stuff out to memory
-(void)flushRecordBuffer{
    
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"b_record"]){
        recordingPath=nil;
        [recordBuffer removeAllObjects];
    }
    
    
    if([recordBuffer count] > flushBufferAt){
        
        //setup a directory if we don't have one
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
                oscPacketLogLine = [NSString stringWithFormat:@"%f: %@",timeStamp,[m address]];
                
                for(OSCValue *v in [m valueArray]){
                   
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
                
                 //NSLog(@"%@",oscPacketLogLine);
                [humanReadableArray addObject:oscPacketLogLine];
            }
            
           
                            
                NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        
                
                // Filenames are UNIXTIME.log
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:humanReadableArray];
                NSError *error = nil;
                NSString *recordPath = [NSString stringWithFormat:@"%@/%f.log",recordingPath,timeStamp];
                
                [data writeToFile:recordPath
                          options:NSDataWritingAtomic
                            error:&error];
            if ([error localizedDescription]){
                NSLog(@"ERROR!: Error writing to disk %@", [error localizedDescription]);
            }

            
            
        });
    }
}


-(void)setupOSCInput{
     if (![[NSUserDefaults standardUserDefaults] boolForKey:@"b_listen"]){
        [OSCmanagerObject deleteAllInputs];
         inPort=nil;
     }else{
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

// Send out the data via OSC
-(void)resetOSC{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [OSCmanagerObject deleteAllInputs];
        [OSCmanagerObject deleteAllOutputs];
    });
}

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



- (void) receivedOSCMessage:(OSCMessage *)m	{
	
	if(OSCOutput){
        [OSCOutput sendThisMessage:m];
    }
    
    // If record option is on, add to buffer
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"b_record"]){
        
        [recordBuffer addObject:m];
        //NSLog(@"%s ... %@",__func__,m);
    }
}




@end
