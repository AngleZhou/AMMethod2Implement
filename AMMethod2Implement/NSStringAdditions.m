//
//  NSStringAdditions.m
//  AMMethod2Implement
//
//  Created by Long on 14-4-15.
//  Copyright (c) 2014年 Tendencystudio. All rights reserved.
//

#import "NSStringAdditions.h"

@implementation NSString (Additions)

- (BOOL)matches:(NSString *)regex
{

    return [self matches:regex range:NSMakeRange(0, self.length)];
}

- (BOOL)matches:(NSString *)regex range:(NSRange)searchRange
{
    
    NSRegularExpression *regularExpression = [NSRegularExpression
                                              regularExpressionWithPattern:regex
                                              options:NSRegularExpressionAnchorsMatchLines
                                              error:NULL];
    BOOL isMatch = [regularExpression numberOfMatchesInString:self options:0 range:searchRange] > 0;
    return isMatch;
}
- (NSArray*)getStringMatchesWithRegex:(NSString *)regex {
    NSError *error;
    NSRegularExpression *regularExpression = [NSRegularExpression
                                              regularExpressionWithPattern:regex
                                              options:NSRegularExpressionAnchorsMatchLines
                                              error:&error];
    __weak NSString *wSelf = self;
    __block NSMutableArray *mArr = [[NSMutableArray alloc] init];
    [regularExpression enumerateMatchesInString:self options:0 range:NSMakeRange(0, self.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        NSString *str = [wSelf substringWithRange:result.range];
        NSRange trimStringRange = [str rangeOfString:@"{"];
        if (trimStringRange.location != NSNotFound) {
            str = [str substringWithRange:NSMakeRange(0, trimStringRange.location)];
            NSLog(@"#2trimString: %@", str);
        }
        NSString *trimString = [str removeSpaceAndNewline];
        [mArr insertObject:trimString atIndex:0];
    }];
    
    return [mArr copy];
}

- (NSInteger)getMatchIndexWithRegexList:(NSArray *)regexList
{
    int i = 0;
    for (NSString *regexItem in regexList) {
        if ([self matches:regexItem]) {
            return i;
        }
        i++;
    }
    return -1;
}

- (NSRange)firstMatch:(NSString *)regex
{
    
    NSRegularExpression *regularExpression = [NSRegularExpression
                                              regularExpressionWithPattern:regex
                                              options:NSRegularExpressionAnchorsMatchLines
                                              error:NULL];
    NSTextCheckingResult *result = [regularExpression firstMatchInString:self options:0 range:NSMakeRange(0, self.length)];
    return result.range;
}

- (NSString *)removeSpaceAndNewline
{
    NSString *temp = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *text = [temp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text;
}

@end
