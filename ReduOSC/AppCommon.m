//
//  AppCommon.m
//  PerformanceSpace
//
//  Created by Andrew on 6/14/13.
//  Copyright (c) 2013 Vox Fera. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "AppCommon.h"

@implementation AppCommon

CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(AppCommon);

- (id)init{
    if (self = [super init]){
        self.isFullscreen=false;
    }
    return self;
}

@end
