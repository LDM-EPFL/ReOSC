//
//  AppCommon.m
//  PerformanceSpace
//
//  Created by Andrew on 6/14/13.
//  Copyright (c) 2013 Vox Fera. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "AppCommon.h"
#import "AppDelegate.h"
// Fixes NSLOG (removes timestamp)
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

@implementation AppCommon

CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(AppCommon);

- (id)init{
    if (self = [super init]){
        _playbackAvailable=false;
        _statusLight=[NSColor grayColor];
        _statusLight_playback=[NSColor grayColor];
        _playbackTimeElapsed=0;
    }
    return self;
}

- (void)setNilValueForKey:(NSString*)key{
    
    if ([key isEqualToString:@"showLoadProgress"]){
        self.showLoadProgress = FALSE;
        return;
    }
}


// Accept drag and drop
-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    
    // If load is in progress don't accept another one
    if ([[AppCommon sharedAppCommon] showLoadProgress]){
        return NO;
    }
    
    [[AppCommon sharedAppCommon] setPlaybackAvailable:FALSE];
    
    NSPasteboard* pbrd = [sender draggingPasteboard];
    NSArray *draggedFilePaths = [pbrd propertyListForType:NSFilenamesPboardType];
    NSString *path=draggedFilePaths[0];
    
    
    // You could drop a .log file...
    NSMutableArray *logfiles=[[NSMutableArray alloc] init];
    if([[[[path lastPathComponent] componentsSeparatedByString:@"."] lastObject]isEqualToString:@"log"]){
        [logfiles addObject:[path lastPathComponent]];
        path = [path stringByDeletingLastPathComponent];
        
    // Or a directory full of them
    }else{
        NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
        logfiles = (NSMutableArray*)[dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.log'"]];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy HH:mm:s"];
    
    // Load log (exit if there are no logfiles to parse)
    NSMutableArray* __strong entireLog=[[NSMutableArray alloc] init];
    if ([logfiles count] == 0){
        NSLog(@"No log files to process %@",path);
        return NO;
    }else{
        BOOL __block haveLogToProcess=TRUE;

        // Show progress bar
        [[AppCommon sharedAppCommon] setDropLoadProgressValue:0.0];
        [[AppCommon sharedAppCommon] setShowLoadProgress:TRUE];
        [[AppCommon sharedAppCommon] setCancelLoad:FALSE];
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            float fileCount=1;
            for (NSString *file in logfiles) {
                
                // Cancel?
                if([[AppCommon sharedAppCommon] cancelLoad]){break;}
                
                // Update progress bar
                fileCount++;
                float percentComplete = ((fileCount/[logfiles count])*100);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (percentComplete == 100){
                        [[AppCommon sharedAppCommon] setValue:FALSE forKey:@"showLoadProgress"];
                        [[AppCommon sharedAppCommon] setDropLoadProgressValue:0.0];
                    }else{
                        [[AppCommon sharedAppCommon] setShowLoadProgress:TRUE];
                        [[AppCommon sharedAppCommon] setDropLoadProgressValue:percentComplete];
                    }
                });
                
                NSString *fileToRead=[[NSString alloc] initWithFormat:@"%@/%@",path,file];
                NSData *data = [NSData dataWithContentsOfFile:fileToRead];
                NSArray *array = (NSArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
                if([array count] == 0){
                    [AppDelegate alertUser:@"Empty Log" info:[NSString stringWithFormat:@"That logfile appears empty."]];

                    NSLog(@"Nothing to process!");
                    haveLogToProcess=FALSE;
                }
                
                for(NSString* logEntry in array){
                   
                    NSArray *parsedEntry = [logEntry componentsSeparatedByString:@" "];
                    [entireLog addObject:parsedEntry];
                }
                
            }
            
            // Postprocess callback
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Hide progress bar
                [[AppCommon sharedAppCommon] setValue:FALSE forKey:@"showLoadProgress"];

                 // Cancel!
                 if(![[AppCommon sharedAppCommon] cancelLoad]){
                     
                     // Do some analysis
                    if (haveLogToProcess){
                        NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[[entireLog objectAtIndex:0][0] doubleValue]];
                        NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[[entireLog lastObject][0] doubleValue]];
                        
                        NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
                        NSDate *durationDate = [NSDate dateWithTimeIntervalSince1970:duration];
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"HH:mm:ss.SS"];
                        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
                        
                        NSDateFormatter *format = [[NSDateFormatter alloc] init];
                        
                        [format setDateFormat:@"MMM dd, yyyy HH:mm:ss.SS"];
                        
                        [[AppCommon sharedAppCommon] setPlaybackAvailable:TRUE];
                        
                        NSString* fileName=[[path componentsSeparatedByString:@"/"] lastObject];
                        [[AppCommon sharedAppCommon]setInput_filename:fileName];
                        [[AppCommon sharedAppCommon]setInput_fullFilePath:path];
                        [[AppCommon sharedAppCommon]setInput_entryCount:[NSString stringWithFormat:@"%li events",(unsigned long)[entireLog count]]];
                        [[AppCommon sharedAppCommon]setInput_duration:[dateFormatter stringFromDate:durationDate]];
                        [[AppCommon sharedAppCommon]setInput_timeStamp:[NSString stringWithFormat:@"%@",[format stringFromDate:startDate]]];
                        
                        [[AppCommon sharedAppCommon] setInput_oscFromLog:entireLog];
                    }
                 }
                
            });
        });
    }

    
    return YES;
}

@end
