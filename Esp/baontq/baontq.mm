#import "PubgLoad.h"
#import <UIKit/UIKit.h>
#import "APIClient.h"
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

void kick_hacker_delayed() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        struct stat st;
        const char* path = oxorany("/Library/MobileSubstrate/DynamicLibraries/VNTOOL.dylib");
        
        if (stat(path, &st) == 0) {
            if (st.st_size != 43209088) { 
                exit(0); 
            }
        }
    
        if (!MenDeal) exit(0);
    });
}

+(void)load {
    [super load];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        APIClient *API = [[APIClient alloc] init];
        
        [API setToken:[NSString stringWithUTF8String:oxorany("pX8HUJ1jrowuQMijQEFZZJOpAOpLbZzl7xlWShlB8vfMBwMolp6bpA6IBW04bDQEiUUj4M/7hRwYD6VApIf9c3kkgQYy6dWE/B69+eT5F0g=")]];
        [API setLanguage:[NSString stringWithUTF8String:oxorany("vi")]];
        [API hideUI:YES];

        [API paid:^{
            syscall(26, 31, 0, 0, 0); 
            
            mainWindow = [UIApplication sharedApplication].keyWindow;
            if (!extraInfo) {
                extraInfo = [PubgLoad new];
            }
            
            // Khởi tạo nút bấm nổi VN
            [extraInfo createFloatingButton];

            MenDeal = true; 
            kick_hacker_delayed(); 
        }];
    });
}

#pragma mark - Floating Button Setup

- (void)createFloatingButton {
    if (self.floatingButton) return;

    // Tạo nút tròn kích thước 50x50 tại góc trái màn hình
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(50, 150, 50, 50);
    
    // Đặt chữ VN và kiểu dáng
    [self.floatingButton setTitle:@"MINH" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    
    // Trang trí giao diện nút (màu nền đen mờ 70%, bo tròn, viền đỏ)
    self.floatingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.floatingButton.layer.cornerRadius = 25.0;
    self.floatingButton.layer.borderWidth = 1.5;
    self.floatingButton.layer.borderColor = [UIColor redColor].CGColor;
    self.floatingButton.clipsToBounds = YES;

    // Sự kiện bấm nút và kéo di chuyển
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:panGesture];

    // Thêm nút nổi vào Window chính
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

    // Giữ nút không bị kéo ra ngoài mép màn hình
    CGRect bounds = self.floatingButton.superview.bounds;
    CGFloat halfWidth = self.floatingButton.bounds.size.width / 2;
    CGFloat halfHeight = self.floatingButton.bounds.size.height / 2;

    newCenter.x = MIN(MAX(newCenter.x, halfWidth), bounds.size.width - halfWidth);
    newCenter.y = MIN(MAX(newCenter.y, halfHeight), bounds.size.height - halfHeight);

    self.floatingButton.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.floatingButton.superview];
}

@end