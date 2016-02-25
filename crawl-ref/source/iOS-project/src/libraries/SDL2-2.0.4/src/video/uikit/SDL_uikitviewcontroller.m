/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2015 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#include "../../SDL_internal.h"

#if SDL_VIDEO_DRIVER_UIKIT

#include "SDL_video.h"
#include "SDL_assert.h"
#include "SDL_hints.h"
#include "../SDL_sysvideo.h"
#include "../../events/SDL_events_c.h"

#import "SDL_uikitviewcontroller.h"
#import "SDL_uikitmessagebox.h"
#include "SDL_uikitvideo.h"
#include "SDL_uikitmodes.h"
#include "SDL_uikitwindow.h"
#include "SDL_uikitappdelegate.h"

#if SDL_IPHONE_KEYBOARD
#include "keyinfotable.h"
#endif

#import "SDVersion.h"
#import "MBProgressHUD.h"
//#import "NSArray+Globbing.h"
#import <glob.h>
#import "SCLAlertView.h"
#import "CTFeedbackViewController.h"

#import "JTSImageViewController.h"
#import "JTSImageInfo.h"



@implementation SDL_uikitviewcontroller {
    CADisplayLink *displayLink;
    int animationInterval;
    void (*animationCallback)(void*);
    void *animationCallbackParam;

#if SDL_IPHONE_KEYBOARD
    UITextField *textField;
#endif
    
    JSDPad *dPad;
    //JSButton* yesButton;
    //JSButton* noButton;
    //JSButton* plusButton;
    //JSButton* minusButton;
    //JSButton* keyboardButton;
    //JSButton* hudButton;
    JSButton* optionsButton;

    BOOL isHudShown;
    NSTimer* dpadTimer;
    
    
    UILongPressGestureRecognizer * longPressGesture;
    UILongPressGestureRecognizer * doubleLongPressGesture;
    UILongPressGestureRecognizer * tripleLongPressGesture;
    UITapGestureRecognizer *singleTap;
    UITapGestureRecognizer *doubleTap;
    UITapGestureRecognizer *tripleTap;
    
    MHWDirectoryWatcher* morgueFilesWatcher;
    
    
    //MBProgressHUD *hud;
    
    BOOL isModifyingUI;
    NSTimer* uiBlickTimer;
    
    float dPadScale;
    float dPadPosX;
    float dPadPosY;
    
    
    MYBlurIntroductionView *introductionView;

    SCLAlertView *alertView;
    
    
    BOOL isRecording;
    
    NSDictionary* raceDict;
    NSDictionary* classDict;

}

@synthesize window;

- (instancetype)initWithSDLWindow:(SDL_Window *)_window
{
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.window = _window;

#if SDL_IPHONE_KEYBOARD
        [self initKeyboard];
#endif
    }
    return self;
}

- (void)dealloc
{
#if SDL_IPHONE_KEYBOARD
    [self deinitKeyboard];
#endif
}

- (void)setAnimationCallback:(int)interval
                    callback:(void (*)(void*))callback
               callbackParam:(void*)callbackParam
{
    [self stopAnimation];

    animationInterval = interval;
    animationCallback = callback;
    animationCallbackParam = callbackParam;

    if (animationCallback) {
        [self startAnimation];
    }
}

- (void)startAnimation
{
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(doLoop:)];
    [displayLink setFrameInterval:animationInterval];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)stopAnimation
{
    [displayLink invalidate];
    displayLink = nil;
}

- (void)doLoop:(CADisplayLink*)sender
{
    /* Don't run the game loop while a messagebox is up */
    if (!UIKit_ShowingMessageBox()) {
        animationCallback(animationCallbackParam);
    }
}

- (void)loadView
{
    /* Do nothing. */
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    const CGSize size = self.view.bounds.size;
    int w = (int) size.width;
    int h = (int) size.height;
    
    SDL_SendWindowEvent(window, SDL_WINDOWEVENT_RESIZED, w, h);

    [self.view setNeedsDisplay];
}

- (void)viewDidAppear:(BOOL)animated
{
    BOOL static firstTime = YES;
    [super viewDidAppear:animated];
    
    if( firstTime )
    {
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        
        firstTime = NO;
        
        float scale = 1;
        if( ( [SDVersion deviceVersion] == iPad2 ) ||
           ( [SDVersion deviceVersion] == iPadAir ) ||
           ( [SDVersion deviceVersion] == iPadAir2 ) ||
           ( [SDVersion deviceVersion] == iPadMini ) ||
           ( [SDVersion deviceVersion] == iPadMini2 ) ||
           ( [SDVersion deviceVersion] == iPadMini3 ) ||
           ( [SDVersion deviceVersion] == iPadMini4 ) )
            scale = 2;
        
        
        dPad = [[JSDPad alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) - 114 * scale, 114 * scale, 114 * scale)];
        dPad.delegate = self;
        dPad.alpha = 0.3f;
        
        dPadScale = [userDefaults floatForKey:@"DPadScale"];
        dPadPosX = [userDefaults floatForKey:@"DPadPosX"];
        dPadPosY = [userDefaults floatForKey:@"DPadPosY"];
        
        if( dPadPosX == -1.0f || dPadPosY == -1.0f )
        {
            dPadPosX = dPad.center.x;
            dPadPosY = dPad.center.y;
            [userDefaults setFloat:dPadPosX forKey:@"DPadPosX"];
            [userDefaults setFloat:dPadPosY forKey:@"DPadPosY"];
            [userDefaults synchronize];
        }
        
        [dPad setTransform:CGAffineTransformMakeScale(dPadScale, dPadScale)];
        [dPad setCenter:CGPointMake(dPadPosX, dPadPosY)];

        [self.view addSubview:dPad];
        //[dPad setHidden:YES];

        
        
        
        optionsButton = [[JSButton alloc] initWithFrame:CGRectMake(0, 0, 28 * scale, 28* scale)];
        [optionsButton setBackgroundImage:[UIImage imageNamed:@"options_silver_on"]];
        [optionsButton setBackgroundImagePressed:[UIImage imageNamed:@"options_silver_off"]];
        optionsButton.delegate = self;
        optionsButton.alpha = 0.3f;
        [self.view addSubview:optionsButton];
    
        
        
    //    keyboardButton = [[JSButton alloc] initWithFrame:CGRectMake(0, 0, 28 * scale, 28* scale)];
    //    [keyboardButton setBackgroundImage:[UIImage imageNamed:@"Show"]];
    //    [keyboardButton setBackgroundImagePressed:[UIImage imageNamed:@"Show_Touched"]];
    //    keyboardButton.delegate = self;
    //    keyboardButton.alpha = 0.3f;
    //    [self.view addSubview:keyboardButton];
        
        
        
    //    plusButton = [[JSButton alloc] initWithFrame:CGRectMake(0, ( 4 + 28* scale ) * 1, 28* scale, 28* scale)];
    //    [plusButton setBackgroundImage:[UIImage imageNamed:@"Plus"]];
    //    [plusButton setBackgroundImagePressed:[UIImage imageNamed:@"Plus_Touched"]];
    //    plusButton.delegate = self;
    //    plusButton.alpha = 0.3f;
    //    [self.view addSubview:plusButton];
        
        
        
    //    minusButton = [[JSButton alloc] initWithFrame:CGRectMake(0, ( 4 + 28 * scale) * 2, 28* scale, 28* scale)];
    //    [minusButton setBackgroundImage:[UIImage imageNamed:@"Minus"]];
    //    [minusButton setBackgroundImagePressed:[UIImage imageNamed:@"Minus_Touched"]];
    //    minusButton.delegate = self;
    //    minusButton.alpha = 0.3f;
    //    [self.view addSubview:minusButton];
        
        
    //    yesButton = [[JSButton alloc] initWithFrame:CGRectMake(0, ( 4 + 28* scale ) * 3, 28* scale, 28* scale)];
    //    [yesButton setBackgroundImage:[UIImage imageNamed:@"Yes"]];
    //    [yesButton setBackgroundImagePressed:[UIImage imageNamed:@"Yes_Touched"]];
    //    yesButton.delegate = self;
    //    yesButton.alpha = 0.3f;
    //    [self.view addSubview:yesButton];
        
        
    //    noButton = [[JSButton alloc] initWithFrame:CGRectMake(0, ( 4 + 28 * scale) * 4, 28* scale, 28* scale)];
    //    [noButton setBackgroundImage:[UIImage imageNamed:@"No"]];
    //    [noButton setBackgroundImagePressed:[UIImage imageNamed:@"No_Touched"]];
    //    noButton.delegate = self;
    //    noButton.alpha = 0.3f;
    //    [self.view addSubview:noButton];
        
        
        
        
    //    hudButton = [[JSButton alloc] initWithFrame:CGRectMake(0, ( 4 + 28* scale ) * 5, 28* scale, 28* scale)];
    //    [hudButton setBackgroundImage:[UIImage imageNamed:@"Hud"]];
    //    [hudButton setBackgroundImagePressed:[UIImage imageNamed:@"Hud"]];
    //    hudButton.delegate = self;
    //    hudButton.alpha = 0.30f;
    //    
    //    isHudShown = NO;
    //    [self.view addSubview:hudButton];
        
        
        longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(hangleLongPress:)];
        longPressGesture.minimumPressDuration = 1.0;
        longPressGesture.delegate = self;
        [self.view addGestureRecognizer:longPressGesture];
        
        doubleLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleLongPress:)];
        doubleLongPressGesture.numberOfTouchesRequired = 2;
        doubleLongPressGesture.minimumPressDuration = 1.0;
        [self.view addGestureRecognizer:doubleLongPressGesture];
        
        
        singleTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(singleTapped:)];
        singleTap.numberOfTapsRequired = 1;
        singleTap.numberOfTouchesRequired = 1;
        singleTap.delegate = self;
        [self.view addGestureRecognizer:singleTap];
        
        doubleTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(doubleTapped:)];
        doubleTap.numberOfTapsRequired = 1;
        doubleTap.numberOfTouchesRequired = 2;
        doubleTap.delegate = self;
        [self.view addGestureRecognizer:doubleTap];
        
//        tripleTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(tripleTapped:)];
//        tripleTap.numberOfTapsRequired = 1;
//        tripleTap.numberOfTouchesRequired = 3;
//        tripleTap.delegate = self;
//        [self.view addGestureRecognizer:tripleTap];
        
        
        tripleLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tripleTapped:)];
        tripleLongPressGesture.numberOfTouchesRequired = 3;
        tripleLongPressGesture.minimumPressDuration = 1.0;
        [self.view addGestureRecognizer:tripleLongPressGesture];
        
        //[singleTap requireGestureRecognizerToFail:doubleTap];
        
        
        UIPinchGestureRecognizer* pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
        [self.view addGestureRecognizer:pinchGestureRecognizer];

        
        
        UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        swipeUp.numberOfTouchesRequired = 1;
        swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
        swipeUp.delegate = self;
        [self.view addGestureRecognizer:swipeUp];
        
        UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        swipeDown.numberOfTouchesRequired = 1;
        swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
        swipeDown.delegate = self;
        [self.view addGestureRecognizer:swipeDown];
        
        
        UISwipeGestureRecognizer *doubleSwipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleSwipe:)];
        doubleSwipeUp.numberOfTouchesRequired = 2;
        doubleSwipeUp.direction = UISwipeGestureRecognizerDirectionUp;
        doubleSwipeUp.delegate = self;
        [self.view addGestureRecognizer:doubleSwipeUp];
        
    //    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    //    swipeLeft.numberOfTouchesRequired = 2;
    //    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    //    swipeLeft.delegate = self;
    //    [self.view addGestureRecognizer:swipeLeft];
    //    
    //    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    //    swipeRight.numberOfTouchesRequired = 2;
    //    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    //    swipeRight.delegate = self;
    //    [self.view addGestureRecognizer:swipeRight];
        
        
        
        NSString* morguePath = [[[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] path] stringByAppendingPathComponent:@"morgue/"];
        morgueFilesWatcher = [MHWDirectoryWatcher directoryWatcherAtPath:morguePath callback:^{
            [morgueFilesWatcher stopWatching];
            [self performSelectorOnMainThread:@selector(morgueFilesDidChange) withObject:nil waitUntilDone:NO];
        }];
        
        self.lockKeyboard = YES;
        isModifyingUI = NO;
        isRecording = NO;
        
        
        // Set GameCenter Manager Delegate
        [[GameCenterManager sharedManager] setDelegate:self];
        
        BOOL available = [[GameCenterManager sharedManager] checkGameCenterAvailability:YES];
        if (available) {
            NSLog( @"GameCenter Available" );
        } else {
            NSLog( @"GameCenter Unavailable" );
        }
        
        
        //      https://crawl.develz.org/tavern/viewtopic.php?f=5&t=4605
        raceDict = @{
            @"Human": @"Hu",
            @"High elf": @"HE",
            @"Deep elf": @"DE",
            @"Sludge elf": @"SE",
            @"Deep Dwarf": @"DD",
            @"Hill Orc": @"HO",
            @"Merfolk": @"Mf",
            @"Halfling": @"Ha",
            @"Kobold": @"Ko",
            @"Spriggan": @"Sp",
            @"Naga": @"Na",
            @"Centaur": @"Ce",
            @"Ogre": @"Og",
            @"Troll": @"Tr",
            @"Minotaur": @"Mi",
            @"Tengu": @"Te",
            @"Draconian": @"Dr",
            @"Demonspawn": @"Ds",
            @"Demigod": @"Dg",
            @"Mummy": @"Mu",
            @"Ghoul": @"Gh",
            @"Vampire": @"Vp",
            @"Felid": @"Fe",
            @"Octopode": @"Op"
            };
        
        classDict = @{ @"Fighter": @"Fi",
                       @"Gladiator": @"Gl",
                       @"Monk": @"Mo",
                       @"Hunter": @"Hu",
                       @"Assassin": @"As",
                       @"Artificer": @"Ar",
                       @"Wanderer": @"Wn",
                       @"Berserker": @"Be",
                       @"Abyssal Knight": @"AK",
                       @"Chaos Knight": @"CK",
                       @"Death Knight": @"DK",
                       @"Priest": @"Pr",
                       @"Healer": @"He",
                       @"Skald": @"Sk",
                       @"Transmuter": @"Tm",
                       @"Warper": @"Wr",
                       @"Arcane Marksman": @"AM",
                       @"Enchanter": @"En",
                       @"Stalker": @"St",
                       @"Wizard": @"Wz",
                       @"Conjurer": @"Cj",
                       @"Summoner": @"Su",
                       @"Necromancer": @"Ne",
                       @"Fire Elementalist": @"FE",
                       @"Ice Elementalist": @"IE",
                       @"Air Elementalist": @"AE",
                       @"Earth Elementalist": @"EE",
                       @"Venom Mage": @"VM"
                      };
        

        [self showIntroductionView];

    }
    else
    {
        SDL_WindowData *data = (__bridge SDL_WindowData *)(self->window->driverdata);
        SDL_VideoDisplay *display = SDL_GetDisplayForWindow(self->window);
        SDL_DisplayModeData *displaymodedata = (__bridge SDL_DisplayModeData *) display->current_mode.driverdata;
        const CGSize size = self.view.bounds.size;
        int w, h;
        
        w = self.view.bounds.size.width;
        h = self.view.bounds.size.height;
        
        SDL_SendWindowEvent(self->window, SDL_WINDOWEVENT_EXPOSED, w, h);
        
        
        
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIKit_GetSupportedOrientations(window);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orient
{
    return ([self supportedInterfaceOrientations] & (1 << orient)) != 0;
}

- (BOOL)prefersStatusBarHidden
{
    return (window->flags & (SDL_WINDOW_FULLSCREEN|SDL_WINDOW_BORDERLESS)) != 0;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    /* We assume most SDL apps don't have a bright white background. */
    return UIStatusBarStyleLightContent;
}

/*
 ---- Keyboard related functionality below this line ----
 */
#if SDL_IPHONE_KEYBOARD

@synthesize textInputRect;
@synthesize keyboardHeight;
@synthesize keyboardVisible;

/* Set ourselves up as a UITextFieldDelegate */
- (void)initKeyboard
{
    textField = [[UITextField alloc] initWithFrame:CGRectZero];
    textField.delegate = self;
    /* placeholder so there is something to delete! */
    textField.text = @" ";

    /* set UITextInputTrait properties, mostly to defaults */
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.enablesReturnKeyAutomatically = NO;
    textField.keyboardAppearance = UIKeyboardAppearanceDefault;
    textField.keyboardType = UIKeyboardTypeDefault;
    textField.returnKeyType = UIReturnKeyDefault;
    textField.secureTextEntry = NO;

    textField.hidden = YES;
    keyboardVisible = NO;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)setView:(UIView *)view
{
    [super setView:view];

    [view addSubview:textField];

    if (keyboardVisible) {
        [self showKeyboard];
    }
}

- (void)deinitKeyboard
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

/* reveal onscreen virtual keyboard */
- (void)showKeyboard
{
    keyboardVisible = YES;
    if (textField.window) {
        [textField becomeFirstResponder];
    }
}

/* hide onscreen virtual keyboard */
- (void)hideKeyboard
{
    keyboardVisible = NO;
    [textField resignFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    CGRect kbrect = [[notification userInfo][UIKeyboardFrameBeginUserInfoKey] CGRectValue];

    /* The keyboard rect is in the coordinate space of the screen/window, but we
     * want its height in the coordinate space of the view. */
    kbrect = [self.view convertRect:kbrect fromView:nil];

    [self setKeyboardHeight:(int)kbrect.size.height];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    [self setKeyboardHeight:0];
}

- (void)updateKeyboard
{
    CGAffineTransform t = self.view.transform;
    CGPoint offset = CGPointMake(0.0, 0.0);
    CGRect frame = UIKit_ComputeViewFrame(window, self.view.window.screen);

    if (self.keyboardHeight) {
        int rectbottom = self.textInputRect.y + self.textInputRect.h;
        int keybottom = self.view.bounds.size.height - self.keyboardHeight;
        if (keybottom < rectbottom) {
            offset.y = keybottom - rectbottom;
        }
    }

    /* Apply this view's transform (except any translation) to the offset, in
     * order to orient it correctly relative to the frame's coordinate space. */
    t.tx = 0.0;
    t.ty = 0.0;
    offset = CGPointApplyAffineTransform(offset, t);

    /* Apply the updated offset to the view's frame. */
    frame.origin.x += offset.x;
    frame.origin.y += offset.y;

    self.view.frame = frame;
}

- (void)setKeyboardHeight:(int)height
{
    keyboardVisible = height > 0;
    keyboardHeight = height;
    [self updateKeyboard];
}

/* UITextFieldDelegate method.  Invoked when user types something. */
- (BOOL)textField:(UITextField *)_textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger len = string.length;

    if (len == 0) {
        /* it wants to replace text with nothing, ie a delete */
        SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_BACKSPACE);
        SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_BACKSPACE);
    } else {
        /* go through all the characters in the string we've been sent and
         * convert them to key presses */
        int i;
        for (i = 0; i < len; i++) {
            unichar c = [string characterAtIndex:i];
            Uint16 mod = 0;
            SDL_Scancode code;

            if (c < 127) {
                /* figure out the SDL_Scancode and SDL_keymod for this unichar */
                code = unicharToUIKeyInfoTable[c].code;
                mod  = unicharToUIKeyInfoTable[c].mod;
            } else {
                /* we only deal with ASCII right now */
                code = SDL_SCANCODE_UNKNOWN;
                mod = 0;
            }

            if (mod & KMOD_SHIFT) {
                /* If character uses shift, press shift down */
                SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_LSHIFT);
            }

            /* send a keydown and keyup even for the character */
            SDL_SendKeyboardKey(SDL_PRESSED, code);
            SDL_SendKeyboardKey(SDL_RELEASED, code);

            if (mod & KMOD_SHIFT) {
                /* If character uses shift, press shift back up */
                SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_LSHIFT);
            }
        }

        SDL_SendKeyboardText([string UTF8String]);
    }

    if( !self.lockKeyboard )
        [self hideKeyboard];
    
    return NO; /* don't allow the edit! (keep placeholder text there) */
}

/* Terminates the editing session */
- (BOOL)textFieldShouldReturn:(UITextField*)_textField
{
    SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_RETURN);
    SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_RETURN);
    SDL_StopTextInput();
    return YES;
}




-(void)dpadTimerHandler:(NSTimer *)timer
{
    //NSLog( @"dpadTimerHandler" );
    
    switch( [[timer userInfo][@"Direction"] integerValue] )
    {
        case JSDPadDirectionLeft:
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_LEFT );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_LEFT );
            break;
            
        case JSDPadDirectionRight:
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_RIGHT );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_RIGHT );
            break;
            
        case JSDPadDirectionUp:
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_UP );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_UP );
            break;
            
        case JSDPadDirectionDown:
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_DOWN );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_DOWN );
            break;
            
        case JSDPadDirectionUpLeft:
            SDL_SendKeyboardText( "y" );
            break;
            
        case JSDPadDirectionUpRight:
            SDL_SendKeyboardText( "u" );
            break;
            
        case JSDPadDirectionDownLeft:
            SDL_SendKeyboardText( "b" );
            break;
            
        case JSDPadDirectionDownRight:
            SDL_SendKeyboardText( "n" );
            break;
        case JSDPadDirectionCenter:
            SDL_SendKeyboardText( "." );
            //NSLog(@"center");
            break;
        default:
            break;
            
    }
    
    //dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.333 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [timer userInfo][@"Direction"]} repeats:NO];
    
    //    [dpadTimer fire];
    
}


#pragma mark - JSDPadDelegate
- (NSString *)stringForDirection:(JSDPadDirection)direction
{
    NSString *string = nil;
    
    switch (direction) {
        case JSDPadDirectionNone:
            string = @"None";
            SDL_SendKeyboardText( "." );
            break;
        case JSDPadDirectionUp:
            string = @"Up";
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_UP );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_UP );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionUp]} repeats:YES];
            
            //[dpadTimer fire];
            //SDL_SendKeyboardText( "8" );
            break;
        case JSDPadDirectionDown:
            string = @"Down";
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_DOWN );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_DOWN );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionDown]} repeats:YES];
            
            //[dpadTimer fire];
            //SDL_SendKeyboardText( "2" );
            break;
        case JSDPadDirectionLeft:
            string = @"Left";
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_LEFT );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_LEFT );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionLeft]} repeats:YES];
            
            //[dpadTimer fire];
            
            //SDL_SendKeyboardText( "h" );
            break;
        case JSDPadDirectionRight:
            string = @"Right";
            SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_RIGHT );
            SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_RIGHT );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionRight]} repeats:YES];
            
            //[dpadTimer fire];
            //SDL_SendKeyboardText( "l" );
            break;
        case JSDPadDirectionUpLeft:
            string = @"Up Left";
            SDL_SendKeyboardText( "y" );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionUpLeft]} repeats:YES];
            break;
        case JSDPadDirectionUpRight:
            string = @"Up Right";
            SDL_SendKeyboardText( "u" );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionUpRight]} repeats:YES];
            break;
        case JSDPadDirectionDownLeft:
            string = @"Down Left";
            SDL_SendKeyboardText( "b" );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionDownLeft]} repeats:YES];
            break;
        case JSDPadDirectionDownRight:
            string = @"Down Right";
            SDL_SendKeyboardText( "n" );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionDownRight]} repeats:YES];
            break;
        case JSDPadDirectionCenter:
            //SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_RETURN );
            //SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_RETURN );
            SDL_SendKeyboardText( "." );
            if( dpadTimer && [dpadTimer isValid] )
            {
                [dpadTimer invalidate];
                dpadTimer = nil;
            }
            dpadTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dpadTimerHandler:) userInfo:@{@"Direction": [NSNumber numberWithInteger:JSDPadDirectionCenter]} repeats:YES];
            break;
        default:
            string = @"NO";
            break;
    }
    
    return string;
}


- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    //[longPressGesture setEnabled:NO];
    [self stringForDirection:direction];
    //NSLog(@"Changing direction to: %@", [self stringForDirection:direction]);
    //[self updateDirectionLabel];
    
}

- (void)dPadDidReleaseDirection:(JSDPad *)dpad
{
    //NSLog(@"Releasing DPad");
    //[self updateDirectionLabel];
    [dpadTimer invalidate];
    dpadTimer = nil;
    //[longPressGesture setEnabled:YES];
}





#pragma mark - JSButtonDelegate

- (void)buttonPressed:(JSButton *)button
{
    //[longPressGesture setEnabled:NO];
}

- (void)buttonReleased:(JSButton *)button
{
//    if ([button isEqual:yesButton])
//    {
//        SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_RETURN );
//        SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_RETURN );
//    }
//    else if ([button isEqual:noButton])
//    {
//        SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_ESCAPE );
//        SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_ESCAPE );
//    }
//    else if ([button isEqual:keyboardButton])
//    {
//        if( SDL_IsScreenKeyboardShown( SDL_GetFocusWindow() ) )
//        {
//            SDL_StopTextInput();
//            [keyboardButton setBackgroundImage:[UIImage imageNamed:@"Show"]];
//            [keyboardButton setBackgroundImagePressed:[UIImage imageNamed:@"Show_Touched"]];
//        }
//        else
//        {
//            SDL_StartTextInput();
//            [keyboardButton setBackgroundImage:[UIImage imageNamed:@"Hide"]];
//            [keyboardButton setBackgroundImagePressed:[UIImage imageNamed:@"Hide_Touched"]];
//        }
//    }
//    else if ([button isEqual:plusButton])
//    {
//        SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_KP_PLUS);
//        SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_KP_PLUS);
//    }
//    else if ([button isEqual:minusButton])
//    {
//        SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_KP_MINUS);
//        SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_KP_MINUS);
//    }
//    else if ([button isEqual:hudButton])
//    {
//        isHudShown = !isHudShown;
//        if( YES == isHudShown )
//        {
//            //[self.view addSubview:dPad];
//            [dPad setHidden:NO];
//            [hudButton setAlpha:0.15];
//        }
//        else
//        {
//            [dPad setHidden:YES];
//            [hudButton setAlpha:0.3];
//        }
//    }
//    else if( [button isEqual:prevButton])
//    {
//        SDL_SendKeyboardText("<");
//    }
//    else if( [button isEqual:nextButton] )
//    {
//        SDL_SendKeyboardText(">");
//        //SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_TAB );
//        //SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_TAB );
//    }
//    else if( [button isEqual:tabButton] )
//    {
//        SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_TAB );
//        SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_TAB );
//    }
    
    if( [button isEqual:optionsButton] )
    {
        [self didTapOptionsButton];
    }
    
    
    //[longPressGesture setEnabled:YES];
}


- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController
{

    [previewController dismissViewControllerAnimated:YES completion:nil];
}

/* @abstract Called when the view controller is finished and returns a set of activity types that the user has completed on the recording. The built in activity types are listed in UIActivity.h. */
- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *> *)activityTypes
{
    NSLog(@"activity - %@",activityTypes);
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isKindOfClass:[self.view class]] /*|| [touch.view isKindOfClass:[noButton class]]*/ )
    {
        return YES;
    }
    
    return NO;
}



-(void)hangleLongPress:(UILongPressGestureRecognizer*)gesture
{
    if( isModifyingUI )
        return;
    
    if( gesture.state == UIGestureRecognizerStateEnded )
    {
        //NSLog( @"Long Press Ended" );
    }
    else if( gesture.state == UIGestureRecognizerStateBegan )
    {
        NSLog( @"Long Pressed" );
        //NSLog( @"Long Press Began" );
        
        CGPoint locationInView = [gesture locationInView: self.view ];
        
        /* send mouse moved event */
        SDL_SendMouseMotion(SDL_GetFocusWindow(), SDL_TOUCH_MOUSEID, 0, locationInView.x, locationInView.y);
        
        /* send mouse down event */
        SDL_SendMouseButton(SDL_GetFocusWindow(), SDL_TOUCH_MOUSEID, SDL_PRESSED, SDL_BUTTON_RIGHT);
        
        SDL_SendMouseButton(SDL_GetFocusWindow(), SDL_TOUCH_MOUSEID, SDL_RELEASED, SDL_BUTTON_RIGHT);
    }
}

-(void)handleDoubleLongPress:(UILongPressGestureRecognizer*)gesture
{
    if( isModifyingUI )
        return;
    
    if( gesture.state == UIGestureRecognizerStateBegan )
    {
        NSLog( @"Double Long Pressed" );
        SDL_SendKeyboardKey( SDL_PRESSED, SDL_SCANCODE_ESCAPE );
        SDL_SendKeyboardKey( SDL_RELEASED, SDL_SCANCODE_ESCAPE );
    }
}



- (void)singleTapped:(UITapGestureRecognizer *)sender
{
    if( isModifyingUI )
        return;
    
    NSLog( @"Single Tapped" );
    
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        CGPoint locationInView = [sender locationInView: self.view ];
        /* send mouse moved event */
        SDL_SendMouseMotion(SDL_GetFocusWindow(), SDL_TOUCH_MOUSEID, 0, locationInView.x, locationInView.y);
        
        /* send mouse down event */
        SDL_SendMouseButton(SDL_GetFocusWindow(), SDL_TOUCH_MOUSEID, SDL_PRESSED, SDL_BUTTON_LEFT);
        
        SDL_SendMouseButton(SDL_GetFocusWindow(), SDL_TOUCH_MOUSEID, SDL_RELEASED, SDL_BUTTON_LEFT);
    }
    
    
}


- (void)doubleTapped:(UITapGestureRecognizer *)sender
{
    if( isModifyingUI )
        return;
    
    NSLog( @"Double Tapped" );
    
    SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_RETURN);
    SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_RETURN);
}


//- (void)tripleTapped:(UILongPressGestureRecognizer*)gesture
-(void)didTapOptionsButton
{
    //if( gesture.state == UIGestureRecognizerStateBegan )
    {
        
        
        NSLog( @"Triple Tapped" );
        
        if( isModifyingUI )
        {
            isModifyingUI = NO;
            
            [uiBlickTimer invalidate];
            [self showAllUI];
            
            NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setFloat:dPadScale forKey:@"DPadScale"];
            [userDefaults setFloat:dPad.center.x forKey:@"DPadPosX"];
            [userDefaults setFloat:dPad.center.y forKey:@"DPadPosY"];
            [userDefaults synchronize];
            
        }
        else
        {
            alertView = [[SCLAlertView alloc] init];
            //Using Selector
            SCLButton* button = [alertView addButton:@"Show tutorial" actionBlock:^(void) {
                NSLog(@"Show tutorial");
                //[self showLeaderboard];
            }];
            button.persistAfterExecution = YES;
            
            //Using Block
            button = [alertView addButton:@"Show keybindings" actionBlock:^(void) {
                NSLog(@"Show keybindings");
                [self showKeybindings];
                
            }];
            button.persistAfterExecution = YES;
            
            //Using Block
            button = [alertView addButton:@"Adjust user interface" actionBlock:^(void) {
                NSLog(@"Adjust user interface");
                isModifyingUI = YES;
                [self adjustUI];
                
                MBProgressHUD* hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                hud.mode = MBProgressHUDModeText;
                hud.labelText = @"Drag or pinch to adjust UI. Tap OPTIONS to confirm.";
    
                [hud hide:YES afterDelay:3];
                
            }];
            button.persistAfterExecution = NO;
            
            
            if( iOSVersionGreaterThanOrEqualTo(@"9") )
            {
                if( isRecording )
                {
                    button = [alertView addButton:@"Stop recording" actionBlock:^(void) {
                        NSLog(@"Stop recording");
                        isRecording = NO;
                        [self stopRecording];
                    }];
                }
                else
                {
                    button = [alertView addButton:@"Start recording" actionBlock:^(void) {
                        NSLog(@"Start recording");
                        isRecording = YES;
                        [self startRecording];
                    }];
                }
                button.persistAfterExecution = NO;
            }
            
            
            alertView.shouldDismissOnTapOutside = YES;
            [alertView showCustom:self image:[UIImage imageNamed:@"stone_soup_icon-512x512"] color:[UIColor blackColor] title:@"Options" subTitle:nil closeButtonTitle:nil duration:0.0f];
            
            
        }

    }
    

}

-(void)showKeybindings
{
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.image = [UIImage imageNamed:@"cheatsheet"];
    imageInfo.referenceRect = alertView.view.bounds;
    imageInfo.referenceView = nil;
    
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Scaled];
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];

}

-(void)showMenuDescription
{
    
}

-(void)adjustUI
{
    dPad.isModifying = YES;
    dPad.panGestureRecognizer.enabled = YES;
    
    uiBlickTimer = [NSTimer scheduledTimerWithTimeInterval:0.333 target:self
                                                                selector:@selector(blinkUI:) userInfo:nil repeats:YES];
}

- (void) blinkUI:(NSTimer *)timer
{
    static BOOL isHidden = NO;
    
    isHidden = isHidden ? NO : YES;

    if( isHidden )
    {
        [dPad setAlpha:0.05f];
        optionsButton.backgroundImage = [UIImage imageNamed:@"options_gold_off"];
    }
    else
    {
        [dPad setAlpha:0.3f];
        optionsButton.backgroundImage = [UIImage imageNamed:@"options_gold_on"];
    }
    
}

-(void) showAllUI
{
    dPad.isModifying = NO;
    dPad.panGestureRecognizer.enabled = NO;
    
    [dPad setAlpha:0.3f];
    optionsButton.backgroundImage = [UIImage imageNamed:@"options_silver_on"];

}




- (void) handleSwipe:(UISwipeGestureRecognizer*)gesture
{
    if( isModifyingUI )
        return;
    
    NSLog( @"Swipe" );
    
    if( UISwipeGestureRecognizerDirectionUp == gesture.direction )
    {
        NSLog( @"UISwipeGestureRecognizerDirectionUp" );
        if( !SDL_IsScreenKeyboardShown( SDL_GetFocusWindow() ) )
        {
            self.lockKeyboard = NO;
            SDL_StartTextInput();
        }
    }
    else if( UISwipeGestureRecognizerDirectionDown == gesture.direction )
    {
        NSLog( @"UISwipeGestureRecognizerDirectionDown" );
        if( SDL_IsScreenKeyboardShown( SDL_GetFocusWindow() ) )
        {
            SDL_StopTextInput();
            self.lockKeyboard = YES;
        }
    }
}



- (void) handleDoubleSwipe:(UISwipeGestureRecognizer*)gesture
{
    if( isModifyingUI )
        return;
    
    NSLog( @"Double Swipe" );
    
    if( UISwipeGestureRecognizerDirectionUp == gesture.direction )
    {
        NSLog( @"UISwipeGestureRecognizerDirectionUp" );
        if( !SDL_IsScreenKeyboardShown( SDL_GetFocusWindow() ) )
        {
            self.lockKeyboard = YES;
            SDL_StartTextInput();
        }
    }
}


-(void)handlePinchGesture:(UIPinchGestureRecognizer*)pinchGestureRecognier
{
    NSLog( @"Pinch" );
    NSLog( @"%f", pinchGestureRecognier.scale );
    const float threshold = 0.1f;

    
    if( pinchGestureRecognier.state == UIGestureRecognizerStateEnded )
    {
        if( pinchGestureRecognier.scale > ( 1.0f + threshold ) )
        {
            if( isModifyingUI )
            {
                dPadScale += 0.25f;
                //NSLog( @"%f", dPadScale );
                if( dPadScale > 2.0f )
                    dPadScale = 2.0f;
                
                [dPad setTransform:CGAffineTransformMakeScale(dPadScale, dPadScale)];
            }
            else
            {
                SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_KP_PLUS);
                SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_KP_PLUS);
                pinchGestureRecognier.scale = 1.0f;
            }
            
        }
        else if( pinchGestureRecognier.scale < ( 1.0f - threshold ) )
        {
            if( isModifyingUI )
            {
                dPadScale -= 0.25f;
                if( dPadScale < 0.5f )
                    dPadScale = 0.5f;
                //NSLog( @"%f", dPadScale );
                [dPad setTransform:CGAffineTransformMakeScale(dPadScale, dPadScale)];
            }
            else
            {
                SDL_SendKeyboardKey(SDL_PRESSED, SDL_SCANCODE_KP_MINUS);
                SDL_SendKeyboardKey(SDL_RELEASED, SDL_SCANCODE_KP_MINUS);
                pinchGestureRecognier.scale = 1.0f;
            }
            
        }
        
        
    }
}


- (NSArray*) arrayWithFilesMatchingPattern: (NSString*) pattern inDirectory: (NSString*) directory {
    
    NSMutableArray* files = [NSMutableArray array];
    glob_t gt;
    NSString* globPathComponent = [NSString stringWithFormat: @"/%@", pattern];
    NSString* expandedDirectory = [directory stringByExpandingTildeInPath];
    char* fullPattern = [[expandedDirectory stringByAppendingPathComponent: globPathComponent] UTF8String];
    if (glob(fullPattern, 0, NULL, &gt) == 0) {
        int i;
        for (i=0; i<gt.gl_matchc; i++) {
            int len = strlen(gt.gl_pathv[i]);
            NSString* filename = [[NSFileManager defaultManager] stringWithFileSystemRepresentation: gt.gl_pathv[i] length: len];
            [files addObject: [NSURL fileURLWithPath:filename]];
        }
    }
    globfree(&gt);
    return [NSArray arrayWithArray: files];
}

-(void)parseMorgueFile
{
    NSString* morguePath = [[[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] path] stringByAppendingPathComponent:@"morgue/"];
    
    NSArray* morgueFiles = [self arrayWithFilesMatchingPattern:@"morgue-*.txt" inDirectory:morguePath];
    
    NSArray *sortedContent = [morgueFiles sortedArrayUsingComparator:
                              ^(NSURL *file1, NSURL *file2)
                              {
                                  // compare
                                  NSDate *file1Date;
                                  [file1 getResourceValue:&file1Date forKey:NSURLContentModificationDateKey error:nil];
                                  
                                  NSDate *file2Date;
                                  [file2 getResourceValue:&file2Date forKey:NSURLContentModificationDateKey error:nil];
                                  
                                  // Ascending:
                                  //return [file1Date compare: file2Date];
                                  // Descending:
                                  return [file2Date compare: file1Date];
                              }];
    
    if( [sortedContent count] > 0 )
    {
        NSLog( @"%@", sortedContent[0] );
        
        long long totalSecs = 0;
        long long totalTurns = 0;
        long long score = 0;
        
        
        NSString* allLines = [NSString stringWithContentsOfURL:sortedContent[0] encoding:NSUTF8StringEncoding error:nil];
        
        //NSLog(@"%@", allLines);
        NSArray* lines = [allLines componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSRegularExpression *regexScore = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\s.*\\(level.*\\)" options:NSRegularExpressionCaseInsensitive error:nil];
        
        NSRegularExpression *regexRaceAndClass = [NSRegularExpression regularExpressionWithPattern:@"^.*\\((.*)\\)\\s+Turns:" options:NSRegularExpressionCaseInsensitive error:nil];
        
        NSRegularExpression *regexTurnsAndTime = [NSRegularExpression regularExpressionWithPattern:@"The game lasted (\\d\\d):(\\d\\d):(\\d\\d) \\((\\d+) turns\\)" options:NSRegularExpressionCaseInsensitive error:nil];
        
        for( NSString* line in lines )
        {
            //NSLog(@"%@", line);
            if( [regexScore numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])] )
            {
                NSArray* matches = [regexScore matchesInString:line options:0 range:NSMakeRange(0, [line length])];
                
                NSTextCheckingResult *match = matches[0];
                NSRange firstRange = [match rangeAtIndex:1];
                NSString* scoreStr = [line substringWithRange:firstRange];
                
                
                score = [scoreStr longLongValue];
                
                
                
                
                
                
            }
            else if( [regexRaceAndClass numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])] )
            {
                NSArray* matches = [regexRaceAndClass matchesInString:line options:0 range:NSMakeRange(0, [line length])];
                
                NSTextCheckingResult* match = matches[0];
                NSRange firstRange = [match rangeAtIndex:1];
                NSString* raceAndClass = [line substringWithRange:firstRange];
                
                NSLog( @"%@", raceAndClass );
                
            }
            else if( [regexTurnsAndTime numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])] )
            {
                NSArray* matches = [regexTurnsAndTime matchesInString:line options:0 range:NSMakeRange(0, [line length])];
                
                NSTextCheckingResult* match = matches[0];
                NSRange firstRange = [match rangeAtIndex:1];
                NSString* hours = [line substringWithRange:firstRange];
                
                NSRange secondRange = [match rangeAtIndex:2];
                NSString* mins = [line substringWithRange:secondRange];
                
                NSRange thirdRange = [match rangeAtIndex:3];
                NSString* secs = [line substringWithRange:thirdRange];
                
                NSRange fourthRange = [match rangeAtIndex:4];
                NSString* turns = [line substringWithRange:fourthRange];
                
                totalSecs = [hours longLongValue] * 60 * 60 + [mins longLongValue] * 60 + [secs longLongValue];
                totalTurns = [turns longLongValue];
                
                NSLog( @"%d secs, %d turns", totalSecs, totalTurns );
            }
        }
        
        [self reportToGameCenter:score time:totalSecs turns:totalTurns];
    }

}

- (void)morgueFilesDidChange
{
    NSLog(@"morgue files did changed" );

    MBProgressHUD* hud = [[MBProgressHUD alloc] initWithView:self.view];
    hud.removeFromSuperViewOnHide = YES;
    hud.mode = MBProgressHUDModeIndeterminate;
    [hud showAnimated:YES whileExecutingBlock:^{
        [self parseMorgueFile];
    } completionBlock:^{
        SCLAlertView *alert = [[SCLAlertView alloc] init];
        //Using Selector
        SCLButton* button = [alert addButton:@"Show leaderboard " actionBlock:^(void) {
            NSLog(@"Show Leaderboard");
            [self showLeaderboard];
        }];
        button.persistAfterExecution = YES;
        
        //Using Block
        button = [alert addButton:@"Rate app" actionBlock:^(void) {
            NSLog(@"Rate app");
            int myAppID = 12345;
            NSString* url = [NSString stringWithFormat: @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%d", myAppID];
            [[UIApplication sharedApplication] openURL: [NSURL URLWithString: url]];
        }];
        button.persistAfterExecution = YES;
        
        //Using Block
        button = [alert addButton:@"Feedback" actionBlock:^(void) {
            NSLog(@"Feedback");
            [self showFeedback];
        }];
        button.persistAfterExecution = YES;
        
        alert.shouldDismissOnTapOutside = NO;
        [alert showCustom:self image:[UIImage imageNamed:@"stone_soup_icon-512x512"] color:[UIColor blackColor] title:@"See you soon" subTitle:@"New record!" closeButtonTitle:@"Ok" duration:0.0f];
        
    }];
    
    
    
    [morgueFilesWatcher startWatching];
}

-(void)reportToGameCenter:(long long)score time:(long long)time turns:(long long)turns
{
    [self reportScore:score];
//    [self reportTime:time];
//    [self reportTurns:turns];
}

#pragma mark - GameCenter Manager Delegate

- (void)showLeaderboard
{
    [[GameCenterManager sharedManager] presentLeaderboardsOnViewController:self withLeaderboard:nil];
}

- (void)reportScore:(long long)score
{
    [[GameCenterManager sharedManager] saveAndReportScore:score leaderboard:@"DungeonCrawlStoneSoup.HighScore" sortOrder:GameCenterSortOrderHighToLow];
    //actionBarLabel.title = [NSString stringWithFormat:@"Score recorded."];
}

- (void)gameCenterManager:(GameCenterManager *)manager authenticateUser:(UIViewController *)gameCenterLoginController {
    [self presentViewController:gameCenterLoginController animated:YES completion:^{
        NSLog(@"Finished Presenting Authentication Controller");
    }];
}

- (void)gameCenterManager:(GameCenterManager *)manager availabilityChanged:(NSDictionary *)availabilityInformation {
    NSLog(@"GC Availabilty: %@", availabilityInformation);
    if ([[availabilityInformation objectForKey:@"status"] isEqualToString:@"GameCenter Available"]) {
//        [self.navigationController.navigationBar setValue:@"GameCenter Available" forKeyPath:@"prompt"];
//        statusDetailLabel.text = @"Game Center is online, the current player is logged in, and this app is setup.";
    } else {
//        [self.navigationController.navigationBar setValue:@"GameCenter Unavailable" forKeyPath:@"prompt"];
//        statusDetailLabel.text = [availabilityInformation objectForKey:@"error"];
    }
    
    GKLocalPlayer *player = [[GameCenterManager sharedManager] localPlayerData];
    if (player) {
        if ([player isUnderage] == NO) {
//            actionBarLabel.title = [NSString stringWithFormat:@"%@ signed in.", player.displayName];
//            playerName.text = player.displayName;
//            playerStatus.text = @"Player is not underage and is signed-in";
//            [[GameCenterManager sharedManager] localPlayerPhoto:^(UIImage *playerPhoto) {
//                playerPicture.image = playerPhoto;
//            }];
//            
//            long long highScore = [[GameCenterManager sharedManager] highScoreForLeaderboard:@"grp.PlayerScores"];
//            NSLog( @"%f", highScore );
            
        } else {
//            playerName.text = player.displayName;
//            playerStatus.text = @"Player is underage";
//            actionBarLabel.title = [NSString stringWithFormat:@"Underage player, %@, signed in.", player.displayName];
        }
    } else {
        //actionBarLabel.title = [NSString stringWithFormat:@"No GameCenter player found."];
    }
}

- (void)gameCenterManager:(GameCenterManager *)manager error:(NSError *)error {
    NSLog(@"GCM Error: %@", error);
    //actionBarLabel.title = error.domain;
}

- (void)gameCenterManager:(GameCenterManager *)manager reportedAchievement:(GKAchievement *)achievement withError:(NSError *)error {
    if (!error) {
        NSLog(@"GCM Reported Achievement: %@", achievement);
//        actionBarLabel.title = [NSString stringWithFormat:@"Reported achievement with %.1f percent completed", achievement.percentComplete];
    } else {
        NSLog(@"GCM Error while reporting achievement: %@", error);
    }
}

- (void)gameCenterManager:(GameCenterManager *)manager reportedScore:(GKScore *)score withError:(NSError *)error {
    if (!error) {
        NSLog(@"GCM Reported Score: %@", score);
        //actionBarLabel.title = [NSString stringWithFormat:@"Reported leaderboard score: %lld", score.value];
    } else {
        NSLog(@"GCM Error while reporting score: %@", error);
    }
}

- (void)gameCenterManager:(GameCenterManager *)manager didSaveScore:(GKScore *)score {
    NSLog(@"Saved GCM Score with value: %lld", score.value);
    //actionBarLabel.title = [NSString stringWithFormat:@"Score saved for upload to GameCenter."];
}

- (void)gameCenterManager:(GameCenterManager *)manager didSaveAchievement:(GKAchievement *)achievement {
    NSLog(@"Saved GCM Achievement: %@", achievement);
    //actionBarLabel.title = [NSString stringWithFormat:@"Achievement saved for upload to GameCenter."];
}


- (void)showFeedback
{
    CTFeedbackViewController *feedbackViewController = [CTFeedbackViewController controllerWithTopics:CTFeedbackViewController.defaultTopics localizedTopics:CTFeedbackViewController.defaultLocalizedTopics];
    //feedbackViewController.toRecipients = @[@"ctfeedback@example.com"];
    feedbackViewController.toRecipients = @[@"MY_EMAIL"];
    feedbackViewController.hidesAdditionalContent = YES;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:feedbackViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}



-(void)showIntroductionView
{
    introductionView = [[MYBlurIntroductionView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    introductionView.delegate = self;
    [introductionView setBackgroundColor:[UIColor blackColor]];
    
    
    MYIntroductionPanel *panelControlDPad = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Use the D-Pad to move your character or cursor." image:nil];

    MYIntroductionPanel *panelGesturesSwipeUpAndDown = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Swipe up to show the keyboard. Swipe down to hide it." image:nil];
    
    MYIntroductionPanel *panelGesturesPinch = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Pinch to zoom in or zoom out." image:nil];

    MYIntroductionPanel *panelGesturesDoubleSwipe = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Double swipe up to show locked keyboard. It can be used to type long strings." image:nil];
    
    MYIntroductionPanel *panelGesturesSingleTap = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Single tap to confirm actions. It behaves like clicking left mouse button." image:nil];
    
    MYIntroductionPanel *panelGesturesSingleLongTap = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Single tap and hold to cancel actions. It behaves like clicking right mouse button." image:nil];
    
    MYIntroductionPanel *panelGesturesDoubleTap = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Double tap to confirm actions. It behaves like the ENTER key on the keyboard." image:nil];
    
    MYIntroductionPanel *panelGesturesDoubleLongTap = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Double tap and hold to cancel actions. It behaves like the ESC key on the keyboard." image:nil];
    
    MYIntroductionPanel *panelGesturesTripleTap = [[MYIntroductionPanel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) title:@"How to play" description:@"Triple tap to show the options menu. You can view gameplay controls, keybindings, or adjust user interface here." image:nil];

    
    
    [introductionView buildIntroductionWithPanels:@[ panelControlDPad,
                                                     panelGesturesSwipeUpAndDown,
                                                     panelGesturesDoubleSwipe,
                                                     panelGesturesPinch,
                                                     panelGesturesSingleTap,
                                                     panelGesturesSingleLongTap,
                                                     panelGesturesDoubleTap,
                                                     panelGesturesDoubleLongTap,
                                                     panelGesturesTripleTap]];
    [self.view addSubview:introductionView];
    
}

#pragma mark - MYIntroductionDelegate Methods
-(void)introduction:(MYBlurIntroductionView *)introductionView didFinishWithType:(MYFinishType)finishType
{
    SDL_WindowData *data = (__bridge SDL_WindowData *)(self->window->driverdata);
    SDL_VideoDisplay *display = SDL_GetDisplayForWindow(self->window);
    SDL_DisplayModeData *displaymodedata = (__bridge SDL_DisplayModeData *) display->current_mode.driverdata;
    const CGSize size = self.view.bounds.size;
    int w, h;
    
    w = self.view.bounds.size.width;
    h = self.view.bounds.size.height;
    
    SDL_SendWindowEvent(self->window, SDL_WINDOWEVENT_EXPOSED, w, h);

}

-(void)introduction:(MYBlurIntroductionView *)introductionView didChangeToPanel:(MYIntroductionPanel *)panel withIndex:(NSInteger)panelIndex
{
    
}


-(void)startRecording
{
    
    optionsButton.backgroundImage = [UIImage imageNamed:@"options_gold_on"];
    optionsButton.backgroundImagePressed = [UIImage imageNamed:@"options_gold_off"];

    RPScreenRecorder *recorder = [RPScreenRecorder sharedRecorder];
    if (!recorder.available) {
        NSLog(@"recorder is not available");
        return;
    }
    if (recorder.recording) {
        NSLog(@"it is recording");
        return;
    }
    [recorder startRecordingWithMicrophoneEnabled:YES handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"start recorder error - %@",error);
        }
        //[self.startBtn setTitle:@"Recording" forState:UIControlStateNormal];
    }];
}

-(void)stopRecording
{
    optionsButton.backgroundImage = [UIImage imageNamed:@"options_silver_on"];
    optionsButton.backgroundImagePressed = [UIImage imageNamed:@"options_silver_off"];
    
    RPScreenRecorder *recorder = [RPScreenRecorder sharedRecorder];
    if (!recorder.recording) {
        return;
    }
    
    
    
    [recorder stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error) {
        if (error) {
            NSLog(@"stop error - %@",error);
        }
        
        previewViewController.previewControllerDelegate = self;
        
        [self presentViewController:previewViewController animated:YES completion:^{
            NSLog(@"complition");
        }];
    }];
}

#endif

@end

/* iPhone keyboard addition functions */
#if SDL_IPHONE_KEYBOARD

static SDL_uikitviewcontroller *
GetWindowViewController(SDL_Window * window)
{
    if (!window || !window->driverdata) {
        SDL_SetError("Invalid window");
        return nil;
    }

    SDL_WindowData *data = (__bridge SDL_WindowData *)window->driverdata;

    return data.viewcontroller;
}

SDL_bool
UIKit_HasScreenKeyboardSupport(_THIS)
{
    return SDL_TRUE;
}

void
UIKit_ShowScreenKeyboard(_THIS, SDL_Window *window)
{
    @autoreleasepool {
        SDL_uikitviewcontroller *vc = GetWindowViewController(window);
        [vc showKeyboard];
    }
}

void
UIKit_HideScreenKeyboard(_THIS, SDL_Window *window)
{
    @autoreleasepool {
        SDL_uikitviewcontroller *vc = GetWindowViewController(window);
        [vc hideKeyboard];
    }
}

SDL_bool
UIKit_IsScreenKeyboardShown(_THIS, SDL_Window *window)
{
    @autoreleasepool {
        SDL_uikitviewcontroller *vc = GetWindowViewController(window);
        if (vc != nil) {
            return vc.isKeyboardVisible;
        }
        return SDL_FALSE;
    }
}

void
UIKit_SetTextInputRect(_THIS, SDL_Rect *rect)
{
    if (!rect) {
        SDL_InvalidParamError("rect");
        return;
    }

    @autoreleasepool {
        SDL_uikitviewcontroller *vc = GetWindowViewController(SDL_GetFocusWindow());
        if (vc != nil) {
            vc.textInputRect = *rect;

            if (vc.keyboardVisible) {
                [vc updateKeyboard];
            }
        }
    }
}


#endif /* SDL_IPHONE_KEYBOARD */

#endif /* SDL_VIDEO_DRIVER_UIKIT */

/* vi: set ts=4 sw=4 expandtab: */
