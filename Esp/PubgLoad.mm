#import "PubgLoad.h"
#import <UIKit/UIKit.h>
#import "JHPP.h"
#import "ImGuiLoad.h"
#import "ImGuiDrawView.h"
#import "oxorany/oxorany.h"

#import <sys/syscall.h>
#import <unistd.h>
#import <sys/stat.h>

bool MenDeal = false;
static PubgLoad *extraInfo;
UIWindow *mainWindow;

@interface PubgLoad()
@property (nonatomic, strong) ImGuiDrawView *vna;
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, assign) BOOL isMenuVisible;
@end

@implementation PubgLoad

+(void)load {
    [super load];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!extraInfo) {
            extraInfo = [PubgLoad new];
        }

        [extraInfo createFloatingButton];

        MenDeal = true;
    });
}

#pragma mark - Floating Button Setup

- (void)createFloatingButton {
    if (self.floatingButton) return;

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(50, 150, 50, 50);

    [self.floatingButton setTitle:@"VN" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];

    self.floatingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.floatingButton.layer.cornerRadius = 25.0;
    self.floatingButton.layer.borderWidth = 1.5;
    self.floatingButton.layer.borderColor = [UIColor redColor].CGColor;
    self.floatingButton.clipsToBounds = YES;

    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:panGesture];

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    [keyWindow addSubview:self.floatingButton];
}

#pragma mark - Menu Actions

- (void)toggleMenu {
    if (!self.vna) {
        self.vna = [[ImGuiDrawView alloc] init];
        [[UIApplication sharedApplication].windows[0].rootViewController.view addSubview:self.vna.view];
    }

    self.isMenuVisible = !self.isMenuVisible;
    [ImGuiDrawView showChange:self.isMenuVisible];
}

#pragma mark - Drag Floating Button

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.floatingButton.superview];
    CGPoint newCenter = CGPointMake(self.floatingButton.center.x + translation.x,
                                    self.floatingButton.center.y + translation.y);

    CGRect bounds = self.floatingButton.superview.bounds;
    CGFloat halfWidth = self.floatingButton.bounds.size.width / 2;
    CGFloat halfHeight = self.floatingButton.bounds.size.height / 2;

    newCenter.x = MIN(MAX(newCenter.x, halfWidth), bounds.size.width - halfWidth);
    newCenter.y = MIN(MAX(newCenter.y, halfHeight), bounds.size.height - halfHeight);

    self.floatingButton.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.floatingButton.superview];
}

@end