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

id(*originalImp)(id, SEL, NSCoder *);

+ (void)load
{
    IMP customImp = class_getMethodImplementation([UIView class], @selector(nested_xib_awakeAfterUsingCoder:));
    Method originalMethod = class_getInstanceMethod([UIView class], @selector(awakeAfterUsingCoder:));
    
    originalImp = (id(*)(id,SEL,NSCoder*))method_setImplementation(originalMethod, customImp);
}

+ (void)initialize
{
    loadingXibs = [NSMutableSet new];

    propertiesToTransfer = @[@"frame", @"autoresizesSubviews", @"autoresizingMask", @"hidden", @"userInteractionEnabled", @"translatesAutoresizingMaskIntoConstraints"];
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
    if ([[NSBundle bundleForClass:[self class]] pathForResource:guessName ofType:@"nib"]) {
        return guessName;
    } else {
        return nil;
    }
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

- (void)drawInterfaceBuilderRect:(CGRect)rect
{
    NSString *xibName = [[[self class] xibName] stringByAppendingPathExtension:@"xib"];
    
    if (xibName) {
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        [[UIColor colorWithWhite:0.93 alpha:1] setFill];
        
        CGContextFillRect(context, self.bounds);
        
        UILabel *label = [[UILabel alloc] initWithFrame:self.bounds];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor colorWithWhite:0.78 alpha:1];
        
        UIFont *baseFont = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:33];
        UIFont *subtitleFont = [baseFont fontWithSize:24];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@"Nested Xib\n" attributes:@{NSFontAttributeName : baseFont}];
        [string appendAttributedString:[[NSAttributedString alloc] initWithString:xibName attributes:@{NSFontAttributeName : subtitleFont}]];
        label.attributedText = string;
        
        [label drawRect:self.bounds];
    }
}

@end
