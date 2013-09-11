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

- (IBAction)saveAction:(id)sender;


// Pop up an alert
+(void)alertUser:(NSString*)alertTitle info:(NSString*)alertMessage;

// Model alert on a sheet
+(void)alertUserOnWindow:(NSWindow*)displayWindow alertTitle:(NSString*)alertTitle info:(NSString*)alertMessage;

// Create a safe temporary working location
// Thx http://www.cocoawithlove.com/2009/07/temporary-files-and-folders-in-cocoa.html
+(NSString*)createTempWorkingFolder;

@end
