//
//  AMAMMethod2Implement.m
//  AMAMMethod2Implement
//
//  Created by Mellong on 14-4-15.
//    Copyright (c) 2014年 Tendencystudio. All rights reserved.
//

#import "AMMethod2Implement.h"
#import "AMIDEHelper.h"
#import "AMSettingWindowController.h"
#import "AMMenuGenerator.h"

static AMMethod2Implement *sharedPlugin;

@interface AMMethod2Implement()
{
    NSArray *_implementMap;
    NSArray *_declareMap;
    NSArray *_implementContent;
}

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) AMSettingWindowController * settingWindowController;

@end

@implementation AMMethod2Implement


+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        
        
    }
    return self;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self initData];
    [self createMenuItem];
}

- (void)createMenuItem
{
    [AMMenuGenerator generateMenuItems:self.bundle version:[self getBundleVersion] target:self];
}

- (NSString *)getBundleVersion
{
    NSString *bundleVersion = [[self.bundle infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    return bundleVersion;
}



- (void)initData
{
    NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:[self.bundle pathForResource:@"RegexData" ofType:@"plist"]];
    _declareMap        = data[kDeclareMap];
    _implementMap      = data[kImplementMap];
    NSArray *implementContents  = data[kImplementContent];
    _implementContent = [self escapeCharacterWithArray:implementContents];
}

- (NSArray *)escapeCharacterWithArray:(NSArray *)array
{
    NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:array.count];
    for (id item in array) {
        if ([item isKindOfClass:[NSArray class]]) {
            [mutableArray addObject:[self escapeCharacterWithArray:item]];
        }else if ([item isKindOfClass:[NSString class]]){
            NSString *stringItem = (NSString *)item;
            stringItem = [stringItem stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
            stringItem = [stringItem stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
            [mutableArray addObject:stringItem];
        }
    }
    return mutableArray;
}

- (void)implementMethod:(NSString *)selectString
{
    NSArray *currentClassName          = [AMIDEHelper getCurrentClassNameByCurrentSelectedRangeWithFileType:AMIDEFileTypeHFile];
    NSArray *methodList                = [selectString componentsSeparatedByString:@";"];
    NSMutableString *stringResult      = [NSMutableString string];
    NSDictionary *selectTextDictionary = nil;
    BOOL shouldSelect                  = YES;
    BOOL hasOpenMFile = NO;
    for (NSString *methodItem in methodList) {
        if (methodItem.length == 0) {
            continue;
        }
        
        

        NSInteger matchIndex = [methodItem getMatchIndexWithRegexList:_declareMap];
        
        if (matchIndex != -1)
        {
            NSString *mfilePath = [AMIDEHelper getMFilePathOfCurrentEditFile];
            if (hasOpenMFile == NO) {
                
                [AMIDEHelper openFile:mfilePath];
                hasOpenMFile = YES;
            }
            
            
            while (![[AMIDEHelper getCurrentEditFilePath] isEqualToString:mfilePath]) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }

            NSTextView *textView = [AMXcodeHelper currentSourceCodeTextView];
            NSString *mFileText  = textView.textStorage.string;
            NSRange contentRange = [AMIDEHelper getClassImplementContentRangeWithClassNameItemList:currentClassName fileText:mFileText fileType:AMIDEFileTypeMFile];
 
            
            NSRegularExpression *regex = [NSRegularExpression
                                          regularExpressionWithPattern:_declareMap[matchIndex]
                                          options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionDotMatchesLineSeparators
                                          error:NULL];
            NSTextCheckingResult *textCheckingResult = [regex firstMatchInString:methodItem options:0 range:NSMakeRange(0, methodItem.length)];
            if (textCheckingResult.range.location != NSNotFound) {
                NSString *result = [methodItem substringWithRange:[textCheckingResult rangeAtIndex:textCheckingResult.numberOfRanges-1]];
                
                
                
                BOOL isImplementFound = NO;
                if (matchIndex == AMImplementTypeMethod) {
                    
                    NSRange textRange = [mFileText rangeOfString:methodItem options:NSCaseInsensitiveSearch];
                    isImplementFound = textRange.location != NSNotFound;
                    
                } else if (matchIndex == AMImplementTypeConstString) {
                    
                    NSString *matchRegex = [NSString stringWithFormat:_implementMap[matchIndex], result];
                    isImplementFound = [mFileText matches:matchRegex range:contentRange];
                    
                }
                
                if (isImplementFound) {
                    if (selectTextDictionary == nil) {
                        selectTextDictionary = @{kSelectTextType:@(matchIndex),
                                                 kSelectTextFirstSelectMethod:matchIndex==AMImplementTypeMethod?methodItem:[NSString stringWithFormat:_implementMap[matchIndex], result]};
                    }
                }else {
                    if (shouldSelect) {
                        selectTextDictionary = @{kSelectTextType:@(matchIndex),
                                                 kSelectTextFirstSelectMethod:matchIndex==AMImplementTypeMethod?methodItem:[NSString stringWithFormat:_implementMap[matchIndex], result]};
                        shouldSelect = NO;
                    }
                    
                    [stringResult appendFormat:_implementContent[matchIndex], result];
                    NSLog(@"Result:%@", result);
                }
                
            }
        }
    }
    
    if (stringResult.length > 0) {
        NSTextView *textView = [AMXcodeHelper currentSourceCodeTextView];
        NSRange contentRange = [AMIDEHelper getClassImplementContentRangeWithClassNameItemList:currentClassName fileText:textView.textStorage.string fileType:AMIDEFileTypeMFile];
        NSRange range        = [AMIDEHelper getInsertRangeWithClassImplementContentRange:contentRange];
        [textView insertText:[stringResult stringByAppendingString:@"\n"] replacementRange:range];
    }
    
    if (selectTextDictionary != nil) {
        NSInteger type = [selectTextDictionary[kSelectTextType] integerValue];
        if (type == AMImplementTypeMethod) {
            NSString *trimString = [selectTextDictionary[kSelectTextFirstSelectMethod] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [AMIDEHelper selectText:trimString];
        }else if (type == AMImplementTypeConstString){
            [AMIDEHelper selectTextWithRegex:selectTextDictionary[kSelectTextFirstSelectMethod] highlightText:@"<#value#>"];
        }
    }
}

- (void)declareMethod:(NSString *)selectString{
    
    NSInteger matchIndex = [selectString getMatchIndexWithRegexList:_declareMap];
    if (matchIndex != -1)
    {
        
        if (matchIndex == AMImplementTypeMethod) {
            NSArray *currentClassName          = [AMIDEHelper getCurrentClassNameByCurrentSelectedRangeWithFileType:AMIDEFileTypeMFile];
            NSString *hfilePath = [AMIDEHelper getHFilePathOfCurrentEditFile];
            [AMIDEHelper openFile:hfilePath];
            
            while (![[AMIDEHelper getCurrentEditFilePath] isEqualToString:hfilePath]) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }

            
            NSTextView *textView               = [AMXcodeHelper currentSourceCodeTextView];
            NSString *hFileText                = textView.textStorage.string;
            
            //************* Angle
            NSString *tryString = selectString;
            NSArray *results = [tryString getStringMatchesWithRegex:_declareMap[0]];
            NSRange contentRange = [AMIDEHelper getClassImplementContentRangeWithClassNameItemList:currentClassName fileText:hFileText fileType:AMIDEFileTypeHFile];
            
            for (NSString *trimString in results) {
                NSString *declareMethod = [trimString stringByAppendingString:@";"];
                NSRange textRange = [hFileText rangeOfString:trimString options:NSCaseInsensitiveSearch range:contentRange];
                if (textRange.location == NSNotFound)
                {
                    NSRange range = [AMIDEHelper getInsertRangeWithClassImplementContentRange:contentRange];
                    if (range.location != NSNotFound) {
                        [textView insertText:[NSString stringWithFormat:@"\n%@\n", declareMethod] replacementRange:range];
                    }
                    
                }
                [AMIDEHelper selectText:declareMethod];
            }
            
        }else if (matchIndex == AMImplementTypeSelector) {
            NSTextView *textView               = [AMXcodeHelper currentSourceCodeTextView];
            NSString *fileText                = textView.textStorage.string;
            NSRegularExpression *regex = [NSRegularExpression
                                          regularExpressionWithPattern:_declareMap[matchIndex]
                                          options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionDotMatchesLineSeparators
                                          error:NULL];
            NSTextCheckingResult *textCheckingResult = [regex firstMatchInString:selectString options:0 range:NSMakeRange(0, selectString.length)];
            if (textCheckingResult.range.location != NSNotFound) {
                NSString *result = [selectString substringWithRange:[textCheckingResult rangeAtIndex:textCheckingResult.numberOfRanges-1]];
                if (result.length > 0) {
                    NSUInteger index = [result rangeOfString:@":"].location == NSNotFound ? 0 : 1;
                    NSString *matchRegex = [NSString stringWithFormat:_implementMap[matchIndex][index], result];
                    NSString *stringResult = [NSString stringWithFormat:_implementContent[matchIndex][index], result];
                    BOOL isImplementFound = [fileText matches:matchRegex range:NSMakeRange(0, fileText.length)];
                    if (!isImplementFound) {
                        NSArray *currentClassName = [AMIDEHelper getCurrentClassNameByCurrentSelectedRangeWithFileType:AMIDEFileTypeMFile];
                        NSRange contentRange      = [AMIDEHelper getClassImplementContentRangeWithClassNameItemList:currentClassName fileText:fileText fileType:AMIDEFileTypeMFile];
                        NSRange range             = [AMIDEHelper getInsertRangeWithClassImplementContentRange:contentRange];
                        [textView insertText:[stringResult stringByAppendingString:@"\n"] replacementRange:range];
                    }
                    [AMIDEHelper selectTextWithRegex:matchRegex highlightText:@""];
                }
            }
        }else if (matchIndex == AMImplementTypeInvocation) {
            NSTextView *textView               = [AMXcodeHelper currentSourceCodeTextView];
            NSString *fileText                = textView.textStorage.string;
            NSRegularExpression *regex = [NSRegularExpression
                                          regularExpressionWithPattern:_declareMap[matchIndex]
                                          options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionDotMatchesLineSeparators
                                          error:NULL];
            NSTextCheckingResult *textCheckingResult = [regex firstMatchInString:selectString options:0 range:NSMakeRange(0, selectString.length)];
            if (textCheckingResult.range.location != NSNotFound) {
                NSString *result = [selectString substringWithRange:[textCheckingResult rangeAtIndex:textCheckingResult.numberOfRanges-1]];
                if (result.length > 0) {
                    NSString *matchRegex = [NSString stringWithFormat:_implementMap[matchIndex], result];
                    BOOL isImplementFound = [fileText matches:matchRegex range:NSMakeRange(0, fileText.length)];
                    NSString *stringResult = [NSString stringWithFormat:_implementContent[matchIndex], result];
                    if (!isImplementFound) {
                        NSArray *currentClassName = [AMIDEHelper getCurrentClassNameByCurrentSelectedRangeWithFileType:AMIDEFileTypeMFile];
                        NSRange contentRange      = [AMIDEHelper getClassImplementContentRangeWithClassNameItemList:currentClassName fileText:fileText fileType:AMIDEFileTypeMFile];
                        NSRange range             = [AMIDEHelper getInsertRangeWithClassImplementContentRange:contentRange];
                        [textView insertText:[stringResult stringByAppendingString:@"\n"] replacementRange:range];
                    }
                    [AMIDEHelper selectTextWithRegex:matchRegex highlightText:@""];
                }
            }
        }else if (matchIndex == AMImplementTypeGetter){
            [self generateGetterMethod:selectString];
        }
    }
}

// For menu item:
- (void)doImplementMethodAction
{

    BOOL isProcessFileType = [[AMIDEHelper getCurrentEditFilePath].pathExtension matches:@"[hm]|mm"];
    if (!isProcessFileType) {
        return;
    }
    NSString *selectString = [AMIDEHelper getCurrentSelectMethod];
    
    if ([AMIDEHelper isHeaderFile]) {
        
        [self implementMethod:selectString];
    }else {
        [self declareMethod:selectString];
        
    }
}

/**
 *  create get method for selected properties
 */
- (void)generateGetterMethod:(NSString*)selectString
{
    NSArray *currentClassName          = [AMIDEHelper getCurrentClassNameByCurrentSelectedRangeWithFileType:AMIDEFileTypeHFile];
    NSTextView *textView = [AMXcodeHelper currentSourceCodeTextView];
    NSString *mFileText  = textView.textStorage.string;
    NSRange contentRange = [AMIDEHelper getClassImplementContentRangeWithClassNameItemList:currentClassName fileText:mFileText fileType:AMIDEFileTypeMFile];
    
    NSArray *methodList                = [selectString componentsSeparatedByString:@";"];
    NSMutableString *stringResult      = [NSMutableString string];
    for (NSString *methodItem in methodList) {
        if (methodItem.length == 0) {
            continue;
        }
        NSInteger matchIndex = [methodItem getMatchIndexWithRegexList:_declareMap];
        if (matchIndex == -1) {
            continue;
        }
        
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:_declareMap[matchIndex]
                                      options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionDotMatchesLineSeparators
                                      error:NULL];
        NSTextCheckingResult *textCheckingResult = [regex firstMatchInString:methodItem options:0 range:NSMakeRange(0, methodItem.length)];
        if (textCheckingResult.range.location != NSNotFound) {
            
            NSString *variable = [methodItem substringWithRange:[textCheckingResult rangeAtIndex:textCheckingResult.numberOfRanges-1]];
            NSString *variableType = [methodItem substringWithRange:[textCheckingResult rangeAtIndex:textCheckingResult.numberOfRanges-2]];
            
            NSString *matchRegex = [NSString stringWithFormat:_implementMap[matchIndex], variable];
            BOOL isImplementFound = [mFileText matches:matchRegex range:contentRange];
            
            if (isImplementFound) {
                continue;
            }
            
            [stringResult appendFormat:_implementContent[matchIndex], variableType, variable,variable,variable];
        }
    }
    
    if (stringResult.length > 0) {
        NSRange range        = [AMIDEHelper getInsertRangeWithClassImplementContentRange:contentRange];
        [textView insertText:[stringResult stringByAppendingString:@"\n"] replacementRange:range];
        [AMIDEHelper selectText:stringResult];
    }
}

- (void)showSettingWindow
{
    if (self.settingWindowController == nil) {
        self.settingWindowController = [[AMSettingWindowController alloc] initWithWindowNibName:@"AMSettingWindowController"];
        self.settingWindowController.bundle = self.bundle;

    }

    [self.settingWindowController showWindow:self.settingWindowController];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
