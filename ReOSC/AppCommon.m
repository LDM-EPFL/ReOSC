//
//  AppCommon.m
//  PerformanceSpace
//
//  Created by Andrew on 6/14/13.
//  Copyright (c) 2013 Vox Fera. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "AppCommon.h"
// Fixes NSLOG (removes timestamp)
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

@implementation AppCommon

CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(AppCommon);

- (id)init{
    if (self = [super init]){
        _playbackAvailable=false;
    }
    return self;
}

// Accept drag and drop
+(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    
    [[AppCommon sharedAppCommon] setPlaybackAvailable:FALSE];
    
    NSPasteboard* pbrd = [sender draggingPasteboard];
    NSArray *draggedFilePaths = [pbrd propertyListForType:NSFilenamesPboardType];
    NSString *path=draggedFilePaths[0];
    //NSArray *parsedPath = [path componentsSeparatedByString:@"/"];
    //NSArray *parsedFilename = [parsedPath[[parsedPath count]-1] componentsSeparatedByString:@"."];
    //NSString* extension = parsedFilename[[parsedFilename count]-1];

    
    //NSLog(@"Trying to read: %@",path);
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    NSArray *logfiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.log'"]];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy HH:mm:ss.SSS"];
    
    // Load log (exit if there are no logfiles to parse)
    NSMutableArray* __strong entireLog=[[NSMutableArray alloc] init];
    if ([logfiles count] == 0){
        return NO;
    }else{
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            float fileCount=1;
            for (NSString *file in logfiles) {
                
                // Update progress bar
                float percentComplete = ((fileCount/[logfiles count])*100);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (percentComplete == 100){
                        [[[AppCommon sharedAppCommon] dropLoadProgress] setHidden:TRUE];
                        [[[AppCommon sharedAppCommon] dropLoadProgress] setDoubleValue:0.0];
                    }else{
                        [[[AppCommon sharedAppCommon] dropLoadProgress] setHidden:FALSE];
                        [[[AppCommon sharedAppCommon] dropLoadProgress] setDoubleValue:percentComplete];
                    }
                });
                
                NSString *fileToRead=[[NSString alloc] initWithFormat:@"%@/%@",path,file];
                NSData *data = [NSData dataWithContentsOfFile:fileToRead];
                NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                for(NSString* logEntry in array){
                    NSArray *parsedEntry = [logEntry componentsSeparatedByString:@" "];
                    [entireLog addObject:parsedEntry];
                }
                fileCount++;
            }
            
            // Postprocess callback
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Do some analysis
                NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[[entireLog objectAtIndex:0][0] doubleValue]];
                NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[[entireLog lastObject][0] doubleValue]];
                
                NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
                NSDate *durationDate = [NSDate dateWithTimeIntervalSince1970:duration];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"HH:mm:ss"];
                [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
                
                NSDateFormatter *format = [[NSDateFormatter alloc] init];
                
                [format setDateFormat:@"MMM dd, yyyy HH:mm"];
                
                [[AppCommon sharedAppCommon] setPlaybackAvailable:TRUE];
                
                NSString* fileName=[[path componentsSeparatedByString:@"/"] lastObject];
                [[AppCommon sharedAppCommon]setInput_filename:fileName];
                [[AppCommon sharedAppCommon]setInput_fullFilePath:path];
                [[AppCommon sharedAppCommon]setInput_entryCount:[NSString stringWithFormat:@"%li log entries",(unsigned long)[entireLog count]]];
                [[AppCommon sharedAppCommon]setInput_duration:[dateFormatter stringFromDate:durationDate]];
                [[AppCommon sharedAppCommon]setInput_timeStamp:[format stringFromDate:startDate]];
                
                [[AppCommon sharedAppCommon] setInput_oscFromLog:entireLog];
                
                
            });
        });
    }

    
    return YES;
}

@end
