//
//  UIView+NestedXib.m
//  Iconic
//
//  Created by Aleksey Garbarev on 03.09.14.
//  Copyright (c) 2014 Code Monastery. All rights reserved.
//

#import "UIView+NestedXib.h"
#import <objc/runtime.h>

@implementation UIView (NestedXib)


static NSMutableSet *loadingXibs;
static NSArray *propertiesToTransfer;

IMP originalImp;

+ (void)load
{
    IMP customImp = class_getMethodImplementation([UIView class], @selector(nested_xib_awakeAfterUsingCoder:));
    Method originalMethod = class_getInstanceMethod([UIView class], @selector(awakeAfterUsingCoder:));
    
    originalImp = method_setImplementation(originalMethod, customImp);
}

+ (void)initialize
{
    loadingXibs = [NSMutableSet new];

    propertiesToTransfer = @[@"backgroundColor", @"frame", @"opaque", @"clipsToBounds", @"autoresizesSubviews",
                             @"autoresizingMask", @"hidden", @"clearsContextBeforeDrawing", @"tintColor", @"alpha",
                             @"exclusiveTouch", @"userInteractionEnabled", @"contentMode"];
    [super initialize];
}

- (id)nested_xib_awakeAfterUsingCoder:(NSCoder *)aDecoder
{
    id result = nil;
    
    if ([self isKindOfClass:[UIView class]]) {
        NSString *nestedXibName = nil;

        nestedXibName = [[self class] xibName];

        if (nestedXibName.length > 0 && ![[self class] isLoadingXib:nestedXibName]) {
            result = [[self class] viewFromXib:nestedXibName originalView:self];
            CFRelease((__bridge const void*)self);
            CFRetain((__bridge const void*)result);
        }
    }
    
    if (!result) {
        result = originalImp(self, @selector(awakeAfterUsingCoder:), aDecoder);
    }
    
    return result;
}

+ (NSString *)xibName
{
    NSString *guessName = NSStringFromClass([self class]);
    if ([[NSBundle mainBundle] pathForResource:guessName ofType:@"nib"]) {
        return guessName;
    } else {
        return nil;
    }
}

+ (NSArray *)customProperties
{
    return @[];
}

+ (BOOL)isLoadingXib:(NSString *)name
{
    return [loadingXibs containsObject:name];
}

+ (id)viewFromXib:(NSString *)xibName originalView:(UIView *)original
{
    [loadingXibs addObject:xibName];
    if ([[original subviews] count] > 0) {
        NSLog(@"Warning: placeholder view contains (%d) subviews. They will be replaced by view from %@ xib", [[original subviews] count], xibName);
    }
    id result = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:nil options:nil] firstObject];
    [loadingXibs removeObject:xibName];
    [self transferPropertiesFromView:original toView:result];
    return result;
}

+ (void)transferPropertiesFromView:(UIView *)src toView:(UIView *)dst
{
    //Transferring autolayout
    dst.translatesAutoresizingMaskIntoConstraints = NO;
    
    for (NSLayoutConstraint *constraint in src.constraints) {
        BOOL replaceFirstItem = [constraint firstItem] == src;
        BOOL replaceSecondItem = [constraint secondItem] == src;
        id firstItem = replaceFirstItem ? dst : constraint.firstItem;
        id secondItem = replaceSecondItem ? dst : constraint.secondItem;
        NSLayoutConstraint *copy = [NSLayoutConstraint constraintWithItem:firstItem attribute:constraint.firstAttribute relatedBy:constraint.relation toItem:secondItem attribute:constraint.secondAttribute multiplier:constraint.multiplier constant:constraint.constant];
        [dst addConstraint:copy];
    }
    
    //Transferring properties
    for (NSString *name in propertiesToTransfer) {
        id value = [src valueForKey:name];
        if ([dst validateValue:&value forKey:name error:nil]) {
            [dst setValue:value forKey:name];
        }
    }
}


@end
