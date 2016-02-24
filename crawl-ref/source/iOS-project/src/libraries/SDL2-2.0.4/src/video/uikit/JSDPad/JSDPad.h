//
//  JSDPad.h
//  Controller
//
//  Created by James Addyman on 28/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, JSDPadDirection)
{
    JSDPadDirectionNone = 0,
	JSDPadDirectionUpLeft,
	JSDPadDirectionUp,
	JSDPadDirectionUpRight,
	JSDPadDirectionLeft,
	JSDPadDirectionCenter,
	JSDPadDirectionRight,
	JSDPadDirectionDownLeft,
	JSDPadDirectionDown,
	JSDPadDirectionDownRight
};

@class JSDPad;

@protocol JSDPadDelegate <NSObject>

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction;
- (void)dPadDidReleaseDirection:(JSDPad *)dPad;

@end

@interface JSDPad : UIView<UIGestureRecognizerDelegate>

@property (nonatomic, strong) IBOutlet id <JSDPadDelegate> delegate;
@property (nonatomic, assign) BOOL isModifying;
@property (nonatomic, strong) UIPanGestureRecognizer* panGestureRecognizer;

- (JSDPadDirection)currentDirection;

@end
