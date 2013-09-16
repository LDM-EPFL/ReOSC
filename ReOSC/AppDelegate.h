//
//  AppDelegate.h
//  ReOSC
//
//  Created by Andrew on 9/5/13.
//  Copyright (c) 2013 FERAL RESEARCH COALITION. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;


// Pop up an alert
+(void)alertUser:(NSString*)alertTitle info:(NSString*)alertMessage;

// Model alert on a sheet
+(void)alertUserOnWindow:(NSWindow*)displayWindow alertTitle:(NSString*)alertTitle info:(NSString*)alertMessage;

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;

@end
