//
//  JSDPad.m
//  Controller
//
//  Created by James Addyman on 28/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "JSDPad.h"

@interface JSDPad () {
	
	JSDPadDirection _currentDirection;
	
	UIImageView *_dPadImageView;
}

@end

@implementation JSDPad

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		[self commonInit];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
		[self commonInit];
	}
	
	return self;
}

- (void)commonInit
{
	_dPadImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"dPad-None"]];
	[_dPadImageView setFrame:CGRectMake(0, 0, [self bounds].size.width, [self bounds].size.height)];
	[self addSubview:_dPadImageView];
	
	_currentDirection = JSDPadDirectionNone;
    
    
//    UIPinchGestureRecognizer* pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
//    pinchGestureRecognizer.delegate = self;
//    [self addGestureRecognizer:pinchGestureRecognizer];
    
    
    // Create a gesture recognizer for detecting drag gesture.
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(handlePan:)];
    self.panGestureRecognizer.delegate = self;
    // Add gesture recognizer to the contentView.
    [self addGestureRecognizer:self.panGestureRecognizer];
    self.panGestureRecognizer.enabled = NO;
    
    
//    
//    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(doubleTapped:)];
//    doubleTap.numberOfTapsRequired = 1;
//    doubleTap.numberOfTouchesRequired = 2;
//    doubleTap.delegate = self;
//    [self addGestureRecognizer:doubleTap];
    
    self.isModifying = NO;
}

- (void)dealloc
{
	self.delegate = nil;
}

- (JSDPadDirection)currentDirection
{
	return _currentDirection;
}

- (JSDPadDirection)directionForPoint:(CGPoint)point
{
	CGFloat x = point.x;
	CGFloat y = point.y;
	
	if (((x < 0) || (x > [self bounds].size.width)) ||
		((y < 0) || (y > [self bounds].size.height)))
	{
		return JSDPadDirectionNone;
	}
	
	NSUInteger column = x / ([self bounds].size.width / 3);
	NSUInteger row = y / ([self bounds].size.height / 3);

	JSDPadDirection direction = (row * 3) + column + 1;
	
	return direction;
}

- (UIImage *)imageForDirection:(JSDPadDirection)direction
{
	UIImage *image = nil;
	
	switch (direction) {
		case JSDPadDirectionNone:
			image = [UIImage imageNamed:@"dPad-None"];
			break;
		case JSDPadDirectionUp:
			image = [UIImage imageNamed:@"dPad-Up"];
			break;
		case JSDPadDirectionDown:
			image = [UIImage imageNamed:@"dPad-Down"];
			break;
		case JSDPadDirectionLeft:
			image = [UIImage imageNamed:@"dPad-Left"];
			break;
		case JSDPadDirectionRight:
			image = [UIImage imageNamed:@"dPad-Right"];
			break;
		case JSDPadDirectionUpLeft:
			image = [UIImage imageNamed:@"dPad-UpLeft"];
			break;
		case JSDPadDirectionUpRight:
			image = [UIImage imageNamed:@"dPad-UpRight"];
			break;
		case JSDPadDirectionDownLeft:
			image = [UIImage imageNamed:@"dPad-DownLeft"];
			break;
		case JSDPadDirectionDownRight:
			image = [UIImage imageNamed:@"dPad-DownRight"];
			break;
        case JSDPadDirectionCenter:
            image = [UIImage imageNamed:@"dPad-Center"];
            break;
		default:
			image = [UIImage imageNamed:@"dPad-None"];
			break;
	}
	
	return image;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    //NSLog( @"touchesBegan" );
    if( self.isModifying )
        return;
    
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	
	JSDPadDirection direction = [self directionForPoint:point];
	
	if ( direction != _currentDirection )
	{
		_currentDirection = direction;
		
		[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
		
		if ([self.delegate respondsToSelector:@selector(dPad:didPressDirection:)])
		{
			[self.delegate dPad:self didPressDirection:_currentDirection];
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    //NSLog( @"touchesMoved" );
    if( self.isModifying )
        return;
    
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	
	JSDPadDirection direction = [self directionForPoint:point];
	
	if ( direction != _currentDirection )
	{
		_currentDirection = direction;
		[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
		
		if ([self.delegate respondsToSelector:@selector(dPad:didPressDirection:)])
		{
			[self.delegate dPad:self didPressDirection:_currentDirection];
		}
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    //NSLog( @"touchesCancelled" );
    if( self.isModifying )
        return;
    
	_currentDirection = JSDPadDirectionNone;
	[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
	
	if ([self.delegate respondsToSelector:@selector(dPadDidReleaseDirection:)])
	{
		[self.delegate dPadDidReleaseDirection:self];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //NSLog( @"touchesEnded" );
    if( self.isModifying )
        return;
    
	_currentDirection = JSDPadDirectionNone;
	[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
	
	if ([self.delegate respondsToSelector:@selector(dPadDidReleaseDirection:)])
	{
		[self.delegate dPadDidReleaseDirection:self];
	}
}


//-(void)handlePinchGesture:(UIPinchGestureRecognizer*)pinchGestureRecognier
//{
//    if( !self.isModifying )
//        return;
//    
//    NSLog( @"dPad Pinch" );
//    
//    float threshold = 0.1f;
//    static float scale = 1.0f;
//    
//    if( pinchGestureRecognier.state == UIGestureRecognizerStateEnded )
//    {
//        NSLog( @"%f", pinchGestureRecognier.scale );
//        if( pinchGestureRecognier.scale > ( 1.0f + threshold ) )
//        {
//            //self.bounds = CGRectMake( self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width+4, self.bounds.size.height+4);
//            //self.frame = CGRectMake( self.frame.origin.x, self.frame.origin.y, self.frame.size.width+4, self.frame.size.height+4);
//            
//            scale += 0.25f;
//        }
//        else if( pinchGestureRecognier.scale < ( 1.0f - threshold ) )
//        {
//            //self.bounds = CGRectMake( self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width-4, self.bounds.size.height-4);
//            //self.frame = CGRectMake( self.frame.origin.x, self.frame.origin.y, self.frame.size.width-4, self.frame.size.height-4);
//
//            scale -= 0.25f;
//        }
//        self.transform = CGAffineTransformMakeScale(scale, scale);
//        pinchGestureRecognier.scale = 1.0f;
//    }
//}



- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    //NSLog( @"handlePan" );

    
    if( !self.isModifying )
        return;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        // Start of the gesture.
        // You could remove any layout constraints that interfere
        // with changing of the position of the content view.
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        // Calculate new center of the view based on the gesture recognizer's
        // translation.
        CGPoint newCenter = self.center;
        newCenter.x += [gestureRecognizer translationInView:self.superview].x;
        newCenter.y += [gestureRecognizer translationInView:self.superview].y;
        
        // Set the new center of the view.
        self.center = newCenter;
        
        // Reset the translation of the recognizer.
        [gestureRecognizer setTranslation:CGPointZero inView:self.superview];
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        // Dragging has ended.
        // You could add layout constraints back to the content view here.
    }
}


//- (void)doubleTapped:(UITapGestureRecognizer *)sender
//{
//    self.isModifying = self.isModifying ? NO : YES;
//    NSLog( @"Double Tapped: %d", self.isModifying );
//    
//}


@end
