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

@interface AppCommon : NSObject{}
CWL_DECLARE_SINGLETON_FOR_CLASS(AppCommon)

// Custom properties for this ap
@property NSImage * screenShot;
@property bool isFullscreen;
@property BigFontView *fontViewController;
@property NSWindow* mainWindow;
@property NSMutableDictionary *midiMappings;


@end


