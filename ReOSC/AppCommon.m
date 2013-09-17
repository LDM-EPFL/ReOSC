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
        self.playbackAvailable=false;
        _statusLight=[NSColor grayColor];
        _statusLight_playback=[NSColor grayColor];
        _statusLight_recording=[NSColor grayColor];
        _playbackTimeElapsed=0;
        _playbackAvailable=FALSE;
    }
    return self;
}

- (void)setNilValueForKey:(NSString*)key{
    if ([key isEqualToString:@"showLoadProgress"]){
        self.showLoadProgress = FALSE;
        return;
    }
}


// Keep light in synch with playbackAvailable
-(BOOL)playbackAvailable{return _playbackAvailable;}
-(void)setPlaybackAvailable:(BOOL)playbackAvailable{
    _playbackAvailable=playbackAvailable;
    if(_playbackAvailable){
        [[AppCommon sharedAppCommon] setStatusLight_playback:[NSColor orangeColor]];
    }else{
        [[AppCommon sharedAppCommon] setStatusLight_playback:[NSColor grayColor]];
    }
}

// Accept drag and drop
-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    
    // If load is in progress don't accept another one
    if ([[AppCommon sharedAppCommon] showLoadProgress]){return NO;}
    
    // Accept drop and pass path to load
    NSPasteboard* pbrd = [sender draggingPasteboard];
    NSArray *draggedFilePaths = [pbrd propertyListForType:NSFilenamesPboardType];
    return [self loadLogFileFromPath:draggedFilePaths];
    
}

// Load logs from a path
-(BOOL)loadLogFileFromPath:(NSArray*)draggedFilePaths{

    NSString *path;
    NSString *fileExt;
    NSString* fileName;
    
    // Playback off while we load
    [[AppCommon sharedAppCommon] setPlaybackAvailable:FALSE];
    
    // You could drop a .log or .tlog file...
    NSMutableArray *logfiles=[[NSMutableArray alloc] init];
    if([[[[draggedFilePaths[0] lastPathComponent] componentsSeparatedByString:@"."] lastObject]isEqualToString:@"log"] ||
       [[[[draggedFilePaths[0] lastPathComponent] componentsSeparatedByString:@"."] lastObject]isEqualToString:@"tlog"]){
        [logfiles addObject:[draggedFilePaths[0] lastPathComponent]];
        path = [draggedFilePaths[0] stringByDeletingLastPathComponent];
        fileExt=[[[draggedFilePaths[0] lastPathComponent] componentsSeparatedByString:@"."] lastObject];

        fileName=[draggedFilePaths[0] lastPathComponent];
        
    // Or a directory full of .log
    }else{
        path = draggedFilePaths[0];
        NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
        logfiles = (NSMutableArray*)[dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.log'"]];
        fileName=[path lastPathComponent];
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
                
                
                // Special .tlog
                NSString *fileToRead;
                NSMutableArray *array=[[NSMutableArray alloc] init];
                if([fileExt isEqualToString:@"tlog"]){
                    fileToRead=[[NSString alloc] initWithFormat:@"%@/%@",path,file];
                    NSString* fileContents=[NSString stringWithContentsOfFile:fileToRead encoding:NSUTF8StringEncoding error:nil];
                    NSArray* fileLines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    for(NSString* line in fileLines){
                        [array addObject:line];
                    }
                    
                // Normal .log
                }else{
                    fileToRead=[[NSString alloc] initWithFormat:@"%@/%@",path,file];
                    NSData *data = [NSData dataWithContentsOfFile:fileToRead];
                    array = (NSMutableArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
                }
                
                // Unpack
                if([array count] == 0){
                    [AppDelegate alertUser:@"Empty Log" info:[NSString stringWithFormat:@"That logfile appears empty."]];
                    NSLog(@"Nothing to process!");
                    haveLogToProcess=FALSE;
                }else{
                    for(NSString* logEntry in array){
                        NSArray *parsedEntry = [logEntry componentsSeparatedByString:@" "];
                        [entireLog addObject:parsedEntry];
                    }
                }

            }
            
            // Postprocess callback
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Hide progress bar
                [[AppCommon sharedAppCommon] setValue:FALSE forKey:@"showLoadProgress"];

                 // If we didn't cancel...
                 if(![[AppCommon sharedAppCommon] cancelLoad]){
                     
                    // Display info about this log
                    if (haveLogToProcess){
                        NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[[entireLog objectAtIndex:0][0] doubleValue]];
                        NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[[entireLog lastObject][0] doubleValue]];
                        
                        NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
                        NSDate *durationDate = [NSDate dateWithTimeIntervalSince1970:duration];
                        
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"HH:mm:ss"];
                        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
                        
                        NSDateFormatter *format = [[NSDateFormatter alloc] init];
                        [format setDateFormat:@"MMM dd, yyyy @ HH:mm a"];
                        
                        [[AppCommon sharedAppCommon] setPlaybackAvailable:TRUE];
                        [[AppCommon sharedAppCommon]setInput_filename:fileName];
                        [[AppCommon sharedAppCommon]setInput_fullFilePath:path];
                        [[AppCommon sharedAppCommon]setInput_entryCount:[NSString stringWithFormat:@"%li events",(unsigned long)[entireLog count]]];
                        [[AppCommon sharedAppCommon]setInput_duration:[NSString stringWithFormat:@"%@ (hours:min:sec)",[dateFormatter stringFromDate:durationDate]]];
                        [[AppCommon sharedAppCommon]setInput_timeStamp:[NSString stringWithFormat:@"%@",[format stringFromDate:startDate]]];
                        [[AppCommon sharedAppCommon] setInput_oscFromLog:entireLog];
                    }
                 }
                
            });
        });
    }

    // Add to recent files menu
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
    return YES;
}

@end
