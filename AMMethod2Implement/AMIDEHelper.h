//
//  AMIDEHelper.h
//  AMMethod2Implement
//
//  Created by Long on 14-4-15.
//  Copyright (c) 2014年 Tendencystudio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AMIDEHelper : NSObject

+ (BOOL)openFile:(NSString *)filePath;
+ (NSString *)getCurrentEditFilePath;
+ (NSString *)getMFilePathOfCurrentEditFile;

+ (void)selectText:(NSString *)text;
+ (void)replaceText:(NSString *)text withNewText:(NSString *)newText;

@end
