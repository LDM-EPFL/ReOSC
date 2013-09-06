//
//  TimelineScrollView.m
//  ReOSC
//
//  Created by Andrew on 9/6/13.
//  Copyright (c) 2013 FERAL RESEARCH COALITION. All rights reserved.
//

#import "TimelineScrollView.h"
#import "AppCommon.h"

@implementation TimelineScrollView

-(BOOL)acceptsFirstResponder{return YES;}
-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {return NSDragOperationCopy;}
-(BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {return YES;}
-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {return [AppCommon performDragOperation:sender];}


-(void)awakeFromNib{
    //Drag and Drop Setup
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}
@end
