//
//  UIView+NestedXib.h
//  Iconic
//
//  Created by Aleksey Garbarev on 03.09.14.
//  Copyright (c) 2014 Code Monastery. All rights reserved.
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface UIView (NestedXib)

+ (NSString *)xibName;

- (void)drawInterfaceBuilderRect:(CGRect)rect;

@end

//Put this into your custom class implementation
#define IB_DRAW - (void)drawRect:(CGRect)rect { [self drawInterfaceBuilderRect:rect]; }