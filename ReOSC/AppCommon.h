//
//  AppCommon.h
//  PerformanceSpace
//
//  Created by Andrew on 6/14/13.
//  Copyright (c) 2013 Vox Fera. All rights reserved.
//
//////////////////////////////////////////////////////////
//  Singleton used to store shared variables
//////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>
#import "CWLSynthesizeSingleton.h"
@class BigFontView;

@interface AppCommon : NSObject{
    BOOL _playbackAvailable;
}
CWL_DECLARE_SINGLETON_FOR_CLASS(AppCommon)

// Custom properties for this ap
@property NSWindow* mainWindow;

@property double dropLoadProgressValue;

@property BOOL playbackAvailable;

@property NSString* input_filename;
@property NSString* input_fullFilePath;
@property NSString* input_entryCount;
@property NSString* input_duration;
@property NSString* input_timeStamp;

@property NSColor*  statusLight;
@property NSColor*  statusLight_playback;
@property NSColor*  statusLight_recording;

@property BOOL cancelLoad;
@property BOOL showLoadProgress;
@property NSTimeInterval playbackTimeElapsed;
@property NSString* playbackDuration;
@property NSDate* recordingBegan;
@property NSTimeInterval recordTimeElapsed;
@property NSString* recordDuration;
@property NSMutableArray* input_oscFromLog;

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender;
-(BOOL)loadLogFileFromPath:(NSArray*)draggedFilePaths;

@end


