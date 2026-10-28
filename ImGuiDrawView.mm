// Code By ttanhdz (tele : @tanhdz1602)
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#include <iostream>
#include <UIKit/UIKit.h>
#include <vector>
#import "pthread.h"
#include <array>
#import <os/log.h>
#include <cmath>
#include <deque>
#include <fstream>
#include <algorithm>
#include <string>
#include <sstream>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <cinttypes>
#include <cerrno>
#include <cctype>
#import <objc/message.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wavailability"

#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_internal.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#include "oxorany/oxorany_include.h"
#import "Helper/Mem.h"
#include "font.h"
#import "Helper/Vector3.h"
#import "Helper/Vector2.h"
#import "Helper/Quaternion.h"
#import "Helper/Monostring.h"
#include "Helper/font.h"
#include "Helper/data.h"
#import "JRMemory.framework/Headers/MemScan.h"

ImFont* verdana_smol;
ImFont* pixel_big = {};
ImFont* pixel_smol = {};

#include "Helper/Obfuscate.h"
#import "Helper/Hooks.h"
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <unistd.h>
#include "Other/dobby_defines.h"
#import "Other/H5hook.h"
#include "Other/Paste.h"

namespace _vstr {
    template <size_t N, uint32_t K>
    struct EncStr {
        char data[N];
        constexpr EncStr(const char (&s)[N]) : data{} {
            uint32_t k = K;
            for (size_t i = 0; i < N; ++i) {
                k = k * 1664525u + 1013904223u;
                uint8_t kb = (uint8_t)((k >> 16) ^ (k >> 8) ^ (i * 131u));
                data[i] = (char)((uint8_t)s[i] ^ kb);
            }
        }
        __attribute__((always_inline)) inline NSString* decode() const {
            char buf[N];
            uint32_t k = K;
            for (size_t i = 0; i < N; ++i) {
                k = k * 1664525u + 1013904223u;
                uint8_t kb = (uint8_t)((k >> 16) ^ (k >> 8) ^ (i * 131u));
                buf[i] = (char)((uint8_t)data[i] ^ kb);
            }
            buf[N-1] = '\0';
            return [NSString stringWithUTF8String:buf];
        }
    };
}
#define _VSTR_KEY ( ((uint32_t)__LINE__ * 2654435761u) ^ ((uint32_t)__COUNTER__ * 2246822519u) ^ 0xDEADBEEFu )
#define DSTR(s) ([]() -> NSString* { \
    constexpr uint32_t _k = _VSTR_KEY; \
    constexpr _vstr::EncStr<sizeof(s), _k> _e(s); \
    return _e.decode(); \
}())
static inline NSString* DSTR_(const char* s) {
    return [NSString stringWithUTF8String:s];
}

#include <sys/sysctl.h>

static inline bool _isBeingDebugged(void) {
    struct kinfo_proc info = {};
    size_t size = sizeof(info);
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, (int)getpid() };
    sysctl(mib, 4, &info, &size, NULL, 0);
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

static inline bool _checkTimingAnomaly(void) {
    struct timespec t1, t2;
    clock_gettime(CLOCK_MONOTONIC, &t1);
    volatile uint64_t x = 0;
    for (int i = 0; i < 1000; i++) x += i;
    clock_gettime(CLOCK_MONOTONIC, &t2);
    uint64_t elapsedNs = (t2.tv_sec - t1.tv_sec) * 1000000000ULL
                       + (t2.tv_nsec - t1.tv_nsec);
    return elapsedNs > 5000000ULL;
}

#define Hook(x, y, z) \
{ \
    NSString* result_##y = StaticInlineHookPatch(("Frameworks/UnityFramework.framework/UnityFramework"), x, nullptr); \
    if (result_##y) { \
        void* result = StaticInlineHookFunction(("Frameworks/UnityFramework.framework/UnityFramework"), x, (void *) y); \
        *(void **) (&z) = (void*) result; \
    } \
}

static float fixLoginTimeout = 60.0f;
static _Atomic(bool) MenDeal = true;

static int   MenuColorTheme  = 0;
static BOOL  isDarkMode      = YES;
static float menuAlpha       = 1.0f;
static float menuScale       = 1.0f;
static int   menuCornerStyle = 0;
static BOOL  isStreamProof   = NO;
static float espLineHue     = 0.0f;
static float espBoxHue      = 0.55f;
static float espSkeletonHue = 0.33f;
static float espFovHue      = 0.0f;

static bool g_showAutoFireButton = false;
static bool g_showUnderButton    = false;

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

static const CGFloat kSidebarWidth     = 115;
static const CGFloat kTabIconSize      = 44;
static const CGFloat kTabIconImageSize = 20;
static const CGFloat kTabSpacing       = 10;
static const CGFloat kPillHeight       = 52;
static const CGFloat kPillSpacing      = 10;
static const CGFloat kContentPadding   = 12;

typedef NS_ENUM(NSInteger, MenuTab) {
    MenuTabAimbot = 0,
    MenuTabESP,
    MenuTabMisc,
    MenuTabSettings,
    MenuTabProfile,
    MenuTabSave
};

@interface ImGuiDrawView () <MTKViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;

@property (nonatomic, strong) UIView *floatingPanel;
@property (nonatomic, strong) UIScrollView *sidebarScrollView;
@property (nonatomic, strong) UIView *sidebarView;
@property (nonatomic, strong) UIView *sidebarBg;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, assign) MenuTab currentTab;
@property (nonatomic, strong) NSMutableArray *tabButtons;
@property (nonatomic, strong) NSMutableDictionary *checkboxStates;
@property (nonatomic, strong) NSMutableDictionary *allCheckboxes;
@property (nonatomic, strong) UIButton *headerButton;
@property (nonatomic, strong) UIButton *themeToggle;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) CGFloat panelWidth;
@property (nonatomic, assign) CGFloat panelHeight;

@property (nonatomic, strong) NSString *keyExpiresAt;
@property (nonatomic, strong) NSDate   *keyExpiryDate;
@property (nonatomic, strong) NSTimer  *keyCountdownTimer;

@property (nonatomic, strong) UIButton *autoFireButtonView;
@property (nonatomic, strong) UISwitch *autoFireSwitch;

@property (nonatomic, strong) UIButton *underButtonView;
@property (nonatomic, strong) UISwitch *underSwitch;

- (void)loadSavedSettings;
- (void)setupFloatingPanel;
- (void)setupSidebar;
- (void)setupHeaderBar;
- (void)setupContentArea;
- (void)loadTabContent:(MenuTab)tab;
- (void)updateSidebarForTab:(MenuTab)tab;
- (void)applyCornerStyle;
- (void)forceUpdateColors;
- (void)toggleTheme;
- (void)changeMenuTheme:(UIButton *)sender;
- (void)changeCornerStyle:(UIButton *)sender;
- (void)settingsToggleTheme:(UIButton *)sender;
- (void)resetSettingsTapped;
- (void)sliderAlphaChanged:(UISlider *)s;
- (void)sliderScaleChanged:(UISlider *)s;
- (void)handleStreamProof:(BOOL)enabled;
- (void)toggleStreamProof:(UIButton *)sender;
- (void)fixLoginTapped;
- (void)feedbackTelegramTapped;
- (void)logoutTapped;
- (void)animateClose;
- (void)handleDrag:(UIPanGestureRecognizer *)g;
- (void)handleAutoFireDrag:(UIPanGestureRecognizer *)gesture;
- (void)autoFireModeUI;
- (void)autoFireSwitchChanged:(UISwitch *)sender;
- (void)toggleNoRecoil:(BOOL)enable;

- (void)underModeUI;
- (void)underSwitchChanged:(UISwitch *)sender;
- (void)handleUnderDrag:(UIPanGestureRecognizer *)gesture;

- (CGFloat)addSectionLabel:(NSString *)text atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addFeaturePill:(NSString *)title sub:(NSString *)sub key:(NSString *)key value:(BOOL)val selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addTwoColsLeft:(NSDictionary *)left right:(NSDictionary *)right atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (NSDictionary *)mkDict:(NSString *)title sub:(NSString *)sub key:(NSString *)key value:(BOOL)val;
- (CGFloat)addIconFeaturePill:(NSString *)title iconName:(NSString *)iconName key:(NSString *)key value:(BOOL)val selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addSliderPill:(NSString *)title value:(CGFloat)val min:(CGFloat)min max:(CGFloat)max selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addHueSlider:(NSString *)title tag:(int)tag hue:(float)hue atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addButtonPill:(NSString *)title selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addColorRow:(NSString *)title r:(float)r g:(float)g b:(float)b tag:(int)tag atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addComboRow:(NSString *)title options:(NSArray *)options optionNames:(const char **)names selectedIdx:(int)sel tag:(NSInteger)tag atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (void)comboOptionTapped:(UIButton *)sender;
- (void)toggleVar:(UIButton *)sender;

- (CGFloat)buildAimbotUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)buildEspUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)buildMiscUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)buildSettingsUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)buildProfileUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)buildSaveUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;
- (CGFloat)addCreditText:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p;

- (void)sliderESPDistanceChanged:(UISlider *)s;
- (void)sliderSpinBotSpeedChanged:(UISlider *)s;
- (void)sliderSpeedChanged:(UISlider *)s;
- (void)sliderFovChanged:(UISlider *)s;
- (void)sliderCamXaChanged:(UISlider *)s;
- (void)sliderAutoFireDelayChanged:(UISlider *)s;
- (void)sliderDelayChanged:(UISlider *)s;
- (void)colorSwatchTapped:(UIButton *)sender;
- (void)applyColor:(float)r g:(float)g b:(float)b toTag:(int)tag swatch:(UIButton *)btn;
- (void)applyHue:(float)hue tag:(int)tag thumb:(UIView *)thumb colorName:(UILabel *)colorName fill:(UIView *)fill trackW:(float)trkW trackX:(float)trkX;
- (void)hueSliderPanned:(UIPanGestureRecognizer *)pan;
- (void)hueSliderTapped:(UITapGestureRecognizer *)tap;

- (void)saveSettings;
- (void)deleteSettings;

- (NSString *)loc:(NSString *)key;
+ (NSArray<NSString *> *)supportedLangCodes;
+ (NSArray<NSString *> *)supportedLangNames;
- (void)langBtnTapped:(UIButton *)sender;

- (void)setKeyExpiryDateFromISO:(NSString *)isoStr;
- (NSString *)keyRemainingString;
- (void)startKeyCountdown;
- (void)tickKeyCountdown;

- (void)runACBypass:(UIButton *)sender;

@end

bool SpeedX50Enabled  = false;
bool NoRecoilEnabled  = false;
bool WallGlowEnabled  = false;

static dispatch_queue_t SpeedRunQueue() {
    static dispatch_queue_t q; static dispatch_once_t o;
    dispatch_once(&o, ^{ q = dispatch_queue_create("vntool.speedrun", DISPATCH_QUEUE_SERIAL); });
    return q;
}

static void ApplySpeedX50(BOOL enable) {
    static std::vector<void*> speedAddrs;
    static bool isSpeedScanned = false;

    dispatch_async(SpeedRunQueue(), ^{
        JRMemoryEngine *engine = new JRMemoryEngine(mach_task_self());

        long long originalVal = 4397530849764387586LL;
        long long patchVal    = 4397530849740000000LL;
        AddrRange range       = {0x100000000, 0x160000000};

        if (enable) {
            if (!isSpeedScanned) {
                engine->JRScanMemory(range, &originalVal, sizeof(long long));
                speedAddrs = engine->getAllResults();
                if (!speedAddrs.empty()) isSpeedScanned = true;
            }

            for (void* addr : speedAddrs) {
                engine->JRWriteMemory((uintptr_t)addr, &patchVal, sizeof(long long));
            }
        } else {
            for (void* addr : speedAddrs) {
                engine->JRWriteMemory((uintptr_t)addr, &originalVal, sizeof(long long));
            }
            speedAddrs.clear();
            isSpeedScanned = false;
        }

        delete engine;
    });
}

@implementation ImGuiDrawView

- (void)toggleNoRecoil:(BOOL)enable {
    static dispatch_once_t onceToken;
    static vector<void*> results;

    JRMemoryEngine *engine = new JRMemoryEngine(mach_task_self());
    AddrRange range = {0x100000000, 0x160000000};

    if (enable) {
        dispatch_once(&onceToken, ^{
            uint32_t search = 1016018816;
            engine->JRScanMemory(range, &search, JR_Search_Type_UInt);
            results = engine->getAllResults();
        });

        uint32_t modify = 180;
        for(int i = 0; i < results.size(); i++) {
            engine->JRWriteMemory((unsigned long long)(results[i]), &modify, JR_Search_Type_UInt);
        }
    } else {
        uint32_t modify = 1016018816;
        for(int i = 0; i < results.size(); i++) {
            engine->JRWriteMemory((unsigned long long)(results[i]), &modify, JR_Search_Type_UInt);
        }
        onceToken = 0;
        results.clear();
    }
    delete engine;
}

#pragma mark - Hook AC

- (void)runACBypass:(UIButton *)sender {
    NSLog(@"[VNTool] Hook AC tapped");
}

#pragma mark - Auto Fire Floating Button

- (void)autoFireModeUI {
    if (self.autoFireButtonView) return;

    self.autoFireButtonView = [[UIButton alloc] initWithFrame:CGRectMake(kWidth - 165, 120, 70, 60)];
    self.autoFireButtonView.backgroundColor = [UIColor clearColor];
    self.autoFireButtonView.layer.cornerRadius = 0;
    self.autoFireButtonView.clipsToBounds = NO;
    self.autoFireButtonView.layer.zPosition = 99999;
    self.autoFireButtonView.layer.borderWidth = 0.0;
    self.autoFireButtonView.layer.borderColor = [UIColor clearColor].CGColor;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 1, 70, 20)];
    label.text = @"AUTO";
    label.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:10];
    label.textColor = [self accentColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.layer.cornerRadius = 0;
    label.layer.masksToBounds = NO;
    [self.autoFireButtonView addSubview:label];

    self.autoFireSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(9.5, 22, 51, 31)];
    self.autoFireSwitch.backgroundColor = [UIColor clearColor];
    self.autoFireSwitch.tintColor = [UIColor clearColor];
    self.autoFireSwitch.onTintColor = [UIColor clearColor];
    self.autoFireSwitch.on = Vars.AutoFire;

    for (UIView *subview in self.autoFireSwitch.subviews) {
        subview.backgroundColor = [UIColor clearColor];
        for (UIView *nestedSub in subview.subviews) {
            nestedSub.backgroundColor = [UIColor clearColor];
        }
    }

    self.autoFireSwitch.layer.cornerRadius = 16.0;
    self.autoFireSwitch.layer.borderWidth = 2.0;
    self.autoFireSwitch.layer.borderColor = Vars.AutoFire
        ? [self accentColor].CGColor
        : [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
    self.autoFireSwitch.clipsToBounds = YES;

    [self.autoFireSwitch addTarget:self
                            action:@selector(autoFireSwitchChanged:)
                  forControlEvents:UIControlEventValueChanged];
    [self.autoFireButtonView addSubview:self.autoFireSwitch];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(handleAutoFireDrag:)];
    [self.autoFireButtonView addGestureRecognizer:pan];

    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    if (window) [window addSubview:self.autoFireButtonView];
}

- (void)autoFireSwitchChanged:(UISwitch * _Nonnull)sender {
    Vars.AutoFire = sender.on;
    [UIView animateWithDuration:0.2 animations:^{
        if (sender.on) {
            sender.layer.borderColor = [self accentColor].CGColor;
        } else {
            sender.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
        }
    }];
}

- (void)handleAutoFireDrag:(UIPanGestureRecognizer * _Nonnull)gesture {
    UIView *v = gesture.view;
    CGPoint t = [gesture translationInView:v.superview];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
        [gesture setTranslation:CGPointZero inView:v.superview];
    }
}

#pragma mark - Under Floating Button

- (void)underModeUI {
    if (self.underButtonView) return;

    self.underButtonView = [[UIButton alloc] initWithFrame:CGRectMake(kWidth - 90, 120, 70, 60)];
    self.underButtonView.backgroundColor = [UIColor clearColor];
    self.underButtonView.layer.cornerRadius = 0;
    self.underButtonView.clipsToBounds = NO;
    self.underButtonView.layer.zPosition = 99999;
    self.underButtonView.layer.borderWidth = 0.0;
    self.underButtonView.layer.borderColor = [UIColor clearColor].CGColor;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 1, 70, 20)];
    label.text = @"UNDER";
    label.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:10];
    label.textColor = [self accentColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.layer.cornerRadius = 0;
    label.layer.masksToBounds = NO;
    [self.underButtonView addSubview:label];

    self.underSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(9.5, 22, 51, 31)];
    self.underSwitch.backgroundColor = [UIColor clearColor];
    self.underSwitch.tintColor = [UIColor clearColor];
    self.underSwitch.onTintColor = [UIColor clearColor];
    self.underSwitch.on = Vars.Underground;

    for (UIView *subview in self.underSwitch.subviews) {
        subview.backgroundColor = [UIColor clearColor];
        for (UIView *nestedSub in subview.subviews) {
            nestedSub.backgroundColor = [UIColor clearColor];
        }
    }

    self.underSwitch.layer.cornerRadius = 16.0;
    self.underSwitch.layer.borderWidth = 2.0;
    self.underSwitch.layer.borderColor = Vars.Underground
        ? [self accentColor].CGColor
        : [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
    self.underSwitch.clipsToBounds = YES;

    [self.underSwitch addTarget:self
                         action:@selector(underSwitchChanged:)
               forControlEvents:UIControlEventValueChanged];
    [self.underButtonView addSubview:self.underSwitch];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(handleUnderDrag:)];
    [self.underButtonView addGestureRecognizer:pan];

    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    if (window) [window addSubview:self.underButtonView];
}

- (void)underSwitchChanged:(UISwitch * _Nonnull)sender {
    Vars.Underground = sender.on;
    [UIView animateWithDuration:0.2 animations:^{
        if (sender.on) {
            sender.layer.borderColor = [self accentColor].CGColor;
        } else {
            sender.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
        }
    }];
}

- (void)handleUnderDrag:(UIPanGestureRecognizer * _Nonnull)gesture {
    UIView *v = gesture.view;
    CGPoint t = [gesture translationInView:v.superview];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
        [gesture setTranslation:CGPointZero inView:v.superview];
    }
}

#pragma mark - Theme & Colors

- (UIColor *)backgroundColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:0.96];
    }
    return [UIColor colorWithRed:0.960 green:0.976 blue:0.988 alpha:1.0];
}

- (UIColor *)textColor {
    if (isDarkMode) return [UIColor whiteColor];
    return [UIColor colorWithRed:0.078 green:0.118 blue:0.180 alpha:1.0];
}

- (UIColor *)secondaryTextColor {
    if (isDarkMode) return [UIColor colorWithWhite:0.55 alpha:1.0];
    return [UIColor colorWithRed:0.420 green:0.478 blue:0.560 alpha:1.0];
}

- (UIColor *)accentColor {
    if (MenuColorTheme == 0) return [UIColor colorWithRed:0.96 green:0.12 blue:0.15 alpha:1.0]; // Reiman Red
    if (MenuColorTheme == 1) return [UIColor colorWithRed:0.000 green:0.520 blue:0.850 alpha:1.0];
    if (MenuColorTheme == 2) return [UIColor colorWithRed:0.000 green:0.700 blue:0.650 alpha:1.0];
    return [UIColor colorWithRed:0.950 green:0.450 blue:0.650 alpha:1.0];
}

- (UIColor *)pillColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:0.125 green:0.125 blue:0.145 alpha:0.95];
    }
    return [UIColor colorWithRed:0.925 green:0.949 blue:0.972 alpha:1.0];
}

- (UIColor *)checkboxOffColor {
    if (isDarkMode) return [UIColor colorWithWhite:0.25 alpha:1.0];
    return [UIColor colorWithRed:0.870 green:0.898 blue:0.925 alpha:1.0];
}

- (UIColor *)glowColor { return [[self accentColor] colorWithAlphaComponent:0.6]; }

- (UIColor *)sidebarBackgroundColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:0.045 green:0.045 blue:0.055 alpha:0.98];
    }
    return [UIColor colorWithRed:0.945 green:0.965 blue:0.984 alpha:1.0];
}

- (UIColor *)sidebarButtonColor:(BOOL)selected {
    if (isDarkMode) {
        return selected ? [UIColor colorWithWhite:0.14 alpha:0.5]
                        : [UIColor clearColor];
    } else {
        return selected ? [[self accentColor] colorWithAlphaComponent:0.18]
                        : [UIColor clearColor];
    }
}

#pragma mark - Setup & Lifecycle

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!self.device) abort();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.IniFilename = nullptr;

    static ImVector<ImWchar> gVietRanges;
    {
        ImFontGlyphRangesBuilder builder;
        builder.AddRanges(io.Fonts->GetGlyphRangesDefault());
        builder.AddRanges(io.Fonts->GetGlyphRangesVietnamese());
        builder.BuildRanges(&gVietRanges);
    }
    ImFontConfig cfg;
    cfg.OversampleH = 2; cfg.OversampleV = 2;
    ImFont* mainFont = io.Fonts->AddFontFromMemoryTTF((void*)NotoSansViet, (int)sizeof(NotoSansViet), 16.0f, &cfg, gVietRanges.Data);
    ImFont* bigFont = io.Fonts->AddFontFromMemoryTTF((void*)NotoSansViet, (int)sizeof(NotoSansViet), 32.0f, &cfg, gVietRanges.Data);

    verdana_smol = mainFont;
    pixel_big    = bigFont;
    pixel_smol   = mainFont;

    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open { MenDeal = open; }
- (MTKView *)mtkView { return (MTKView *)self.view; }

- (void)loadView {
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)updateIOWithTouchEvent:(UIEvent *)event {
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);
    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
            hasActiveTouch = YES; break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device          = self.device;
    self.mtkView.delegate        = self;
    self.mtkView.clearColor      = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor clearColor];
    self.mtkView.clipsToBounds   = YES;

    game_sdk->init();
    initDoubleGunHook();
    initAutoFireHook();
    initResetGuestHook();
    // ✅ Đã xoá: initFastMedkitHook(); initHighFPS120Hook();
    [self loadSavedSettings];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_t spinThread;
        pthread_create(&spinThread, NULL, SpinBotLoop, NULL);
        pthread_detach(spinThread);
    });

    static dispatch_once_t silentOnce;
    dispatch_once(&silentOnce, ^{
        std::thread(AimSilentVoidInternal).detach();
        std::thread(SilentTargetTrackVoidInternal).detach();
    });

    self.panelWidth  = 560;
    self.panelHeight = 370;
    self.currentTab = MenuTabAimbot;
    self.tabButtons = [NSMutableArray array];
    self.checkboxStates = [NSMutableDictionary dictionary];
    self.allCheckboxes = [NSMutableDictionary dictionary];

    [self setupFloatingPanel];
    [self setupSidebar];
    [self setupHeaderBar];
    [self setupContentArea];

    [self loadTabContent:self.currentTab];
    [self updateSidebarForTab:self.currentTab];
}

#pragma mark - UIKit Setup

- (void)setupFloatingPanel {
    self.floatingPanel = [[UIView alloc] initWithFrame:CGRectMake(40, 40, self.panelWidth, self.panelHeight)];
    self.floatingPanel.backgroundColor = [self backgroundColor];
    self.floatingPanel.clipsToBounds = YES;
    self.floatingPanel.layer.masksToBounds = YES;
    self.floatingPanel.layer.cornerRadius = 16.0f;
    self.floatingPanel.layer.borderWidth = 0.8f;
    self.floatingPanel.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:0.35].CGColor;
    self.floatingPanel.alpha = menuAlpha;
    self.floatingPanel.transform = CGAffineTransformMakeScale(menuScale, menuScale);
    [self.view addSubview:self.floatingPanel];

    // Subtle red glow behind header
    UIView *glow = [[UIView alloc] initWithFrame:CGRectMake(kSidebarWidth, 0, self.panelWidth - kSidebarWidth, 42)];
    glow.backgroundColor = [[self accentColor] colorWithAlphaComponent:0.15];
    glow.layer.cornerRadius = 20.0f;
    glow.layer.shadowColor = [self accentColor].CGColor;
    glow.layer.shadowRadius = 18.0f;
    glow.layer.shadowOpacity = 0.5f;
    glow.layer.shadowOffset = CGSizeZero;
    [self.floatingPanel addSubview:glow];

    // Footer: "Login: Success!" status label
    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(kSidebarWidth, self.panelHeight - 26, self.panelWidth - kSidebarWidth, 20)];
    footerLabel.text = @"Login: Success!";
    footerLabel.textColor = [self accentColor];
    footerLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.layer.shadowColor = [self accentColor].CGColor;
    footerLabel.layer.shadowRadius = 6.0f;
    footerLabel.layer.shadowOpacity = 0.6f;
    footerLabel.layer.shadowOffset = CGSizeZero;
    [self.floatingPanel addSubview:footerLabel];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingPanel addGestureRecognizer:pan];
}

- (void)handleDrag:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}

- (void)setupSidebar {
    self.sidebarBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSidebarWidth, self.panelHeight)];
    self.sidebarBg.backgroundColor = [self sidebarBackgroundColor];
    [self.floatingPanel addSubview:self.sidebarBg];
    [self applyCornerStyle];

    // Vertical separator line
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(kSidebarWidth - 0.5, 0, 0.5, self.panelHeight)];
    sep.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.3];
    [self.floatingPanel addSubview:sep];

    NSArray *titles = @[@"Aim", @"Esp", @"Misc", @"Setting"];
    NSArray *iconNames = @[@"scope", @"eye", @"shield", @"gearshape"];

    CGFloat startY = 70.0f;
    CGFloat btnW = kSidebarWidth - 14.0f;
    CGFloat btnH = 44.0f;
    CGFloat spacing = 8.0f;

    self.sidebarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSidebarWidth, self.panelHeight)];
    [self.sidebarBg addSubview:self.sidebarView];

    for (int i = 0; i < 4; i++) {
        CGFloat btnX = 7.0f;
        CGFloat btnY = startY + i * (btnH + spacing);

        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(btnX, btnY, btnW, btnH)];
        btn.backgroundColor = [self sidebarButtonColor:(i == self.currentTab)];
        btn.layer.cornerRadius = 8.0f;
        btn.tag = i;

        // Icon
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(10, (btnH - 20) / 2.0f, 20, 20)];
        UIImage *img = [UIImage systemImageNamed:iconNames[i]];
        if (img) {
            iv.image = [img imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]];
        }
        iv.tintColor = (i == self.currentTab) ? [self accentColor] : [self secondaryTextColor];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.tag = 100;
        [btn addSubview:iv];

        // Label
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(36, 0, btnW - 42, btnH)];
        lbl.text = titles[i];
        lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        lbl.textColor = (i == self.currentTab) ? [UIColor whiteColor] : [self secondaryTextColor];
        lbl.tag = 101;
        [btn addSubview:lbl];

        // Indicator pill on the right edge
        UIView *ind = [[UIView alloc] initWithFrame:CGRectMake(btnW - 3.5, 6, 3.5, btnH - 12)];
        ind.backgroundColor = [self accentColor];
        ind.layer.cornerRadius = 1.75f;
        ind.layer.shadowColor = [self accentColor].CGColor;
        ind.layer.shadowRadius = 4.0f;
        ind.layer.shadowOpacity = 0.8f;
        ind.layer.shadowOffset = CGSizeZero;
        ind.tag = 102;
        ind.hidden = (i != self.currentTab);
        [btn addSubview:ind];

        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.sidebarView addSubview:btn];
        [self.tabButtons addObject:btn];
    }
}

- (void)setupHeaderBar {
    CGFloat hdrH = 54.0f;

    // Header Title: "REIMAN PRIME"
    NSMutableAttributedString *titleAttr = [[NSMutableAttributedString alloc] init];
    [titleAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@"REIMAN "
        attributes:@{
            NSForegroundColorAttributeName: [self accentColor],
            NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy],
            NSKernAttributeName: @(1.5)
        }]];
    [titleAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@"PRIME"
        attributes:@{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy],
            NSKernAttributeName: @(1.5)
        }]];

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(kSidebarWidth + 14, 12, 220, 32)];
    headerTitle.attributedText = titleAttr;
    headerTitle.layer.shadowColor = [self accentColor].CGColor;
    headerTitle.layer.shadowRadius = 8.0f;
    headerTitle.layer.shadowOpacity = 0.6f;
    headerTitle.layer.shadowOffset = CGSizeZero;
    [self.floatingPanel addSubview:headerTitle];

    // Version V1.0
    UILabel *verLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.panelWidth - 95, 16, 50, 24)];
    verLabel.text = @"V1.0";
    verLabel.textColor = [self accentColor];
    verLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    verLabel.textAlignment = NSTextAlignmentRight;
    [self.floatingPanel addSubview:verLabel];

    // Close Button [x]
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(self.panelWidth - 38, 14, 26, 26);
    self.closeButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.4];
    self.closeButton.layer.cornerRadius = 13.0f;
    [self.closeButton setImage:[[UIImage systemImageNamed:@"xmark"]
        imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    self.closeButton.tintColor = [UIColor whiteColor];
    [self.closeButton addTarget:self action:@selector(animateClose) forControlEvents:UIControlEventTouchUpInside];
    [self.floatingPanel addSubview:self.closeButton];

    // Divider line below header
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(kSidebarWidth, hdrH - 0.5, self.panelWidth - kSidebarWidth, 0.5)];
    line.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.3];
    [self.floatingPanel addSubview:line];
}

- (void)setupContentArea {
    CGFloat hdrH = 54.0f;
    CGFloat footerH = 28.0f;
    CGFloat h = self.panelHeight - hdrH - footerH;
    CGFloat w = self.panelWidth - kSidebarWidth;

    self.contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(kSidebarWidth, hdrH, w, h)];
    self.contentScrollView.showsVerticalScrollIndicator = YES;
    self.contentScrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.contentScrollView.alwaysBounceVertical = YES;
    [self.floatingPanel addSubview:self.contentScrollView];

    self.contentContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    [self.contentScrollView addSubview:self.contentContainer];
}

#pragma mark - Tab Logic

- (void)tabButtonTapped:(UIButton *)sender {
    if (sender.tag == self.currentTab) return;
    self.currentTab = (MenuTab)sender.tag;
    [self updateSidebarForTab:self.currentTab];
    [self loadTabContent:self.currentTab];
}

- (void)updateSidebarForTab:(MenuTab)tab {
    for (UIButton *btn in self.tabButtons) {
        BOOL sel = (btn.tag == tab);
        UIImageView *iv = [btn viewWithTag:100];
        UILabel *lbl = [btn viewWithTag:101];
        UIView *ind = [btn viewWithTag:102];

        iv.tintColor = sel ? [self accentColor] : [self secondaryTextColor];
        lbl.textColor = sel ? [UIColor whiteColor] : [self secondaryTextColor];
        btn.backgroundColor = [self sidebarButtonColor:sel];
        ind.hidden = !sel;
    }
}

- (void)loadTabContent:(MenuTab)tab {
    for (UIView *v in self.contentContainer.subviews) [v removeFromSuperview];

    CGFloat y = 8;
    CGFloat w = self.contentScrollView.frame.size.width - 24;
    CGFloat p = 12;

    switch (tab) {
        case MenuTabAimbot:   y = [self buildAimbotUI:y width:w padding:p]; break;
        case MenuTabESP:      y = [self buildEspUI:y width:w padding:p]; break;
        case MenuTabMisc:     y = [self buildMiscUI:y width:w padding:p]; break;
        case MenuTabSettings: y = [self buildSettingsUI:y width:w padding:p]; break;
        default: break;
    }

    self.contentContainer.frame = CGRectMake(0, 0, w + 24, y + 15);
    self.contentScrollView.contentSize = self.contentContainer.bounds.size;
}

- (void)loadSavedSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (![ud objectForKey:@"sv_marker"]) return;

    Vars.Aimbot         = [ud boolForKey:@"sv_Aimbot"];
    Vars.AimKillSend    = [ud boolForKey:@"sv_AimKillSend"];
    Vars.VisibleCheck   = [ud boolForKey:@"sv_VisibleCheck"];
    Vars.IgnoreKnocked  = [ud boolForKey:@"sv_IgnoreKnocked"];
    Vars.AimFov         = [ud floatForKey:@"sv_AimFov"];
    Vars.AimSpeed       = [ud floatForKey:@"sv_AimSpeed"];
    Vars.AimHitbox      = (int)[ud integerForKey:@"sv_AimHitbox"];
    Vars.AimMode        = (int)[ud integerForKey:@"sv_AimMode"];
    Vars.AimWhen        = (int)[ud integerForKey:@"sv_AimWhen"];

    Vars.Enable          = [ud boolForKey:@"sv_Enable"];
    Vars.Box             = [ud boolForKey:@"sv_Box"];
    Vars.lines           = [ud boolForKey:@"sv_lines"];
    Vars.Health          = [ud boolForKey:@"sv_Health"];
    Vars.Name            = [ud boolForKey:@"sv_Name"];
    Vars.skeleton        = [ud boolForKey:@"sv_skeleton"];
    Vars.Distance        = [ud boolForKey:@"sv_Distance"];
    Vars.circlepos       = [ud boolForKey:@"sv_circlepos"];
    Vars.enemycount      = [ud boolForKey:@"sv_enemycount"];
    if ([ud objectForKey:@"sv_espDrawDistance"])
        Vars.espDrawDistance = [ud floatForKey:@"sv_espDrawDistance"];

    Vars.SpinBotEnabled = [ud boolForKey:@"sv_SpinBot"];
    Vars.SpinBotSpeed   = [ud floatForKey:@"sv_SpinSpeed"];
    Vars.camxa          = [ud boolForKey:@"sv_camxa"];
    Vars.CamXaValue     = [ud floatForKey:@"sv_CamXaValue"];
    Vars.AIRPlayer      = [ud boolForKey:@"sv_AIRPlayer"];
    Vars.telekill       = [ud boolForKey:@"sv_telekill"];
    Vars.Nangdich       = [ud boolForKey:@"sv_Nangdich"];

    NSString *lang = [ud stringForKey:@"vntool_lang"] ?: @"vi";
    extern int g_espLang;
    NSString *espLang = [ud stringForKey:@"vntool_esp_lang"] ?: lang;
    g_espLang = [espLang isEqualToString:@"vi"] ? 1 : 0;

    Vars.AimRandomEnable = [ud boolForKey:@"sv_AimRandom"];
    if ([ud objectForKey:@"sv_AimRandomMode"]) Vars.AimRandomMode = (int)[ud integerForKey:@"sv_AimRandomMode"];
    Vars.SilentAim    = [ud boolForKey:@"sv_SilentAim"];
    Vars.SilentFov    = [ud floatForKey:@"sv_SilentFov"] ?: 150.0f;

    Vars.noreload       = [ud boolForKey:@"sv_noreload"];
    Vars.vohandan       = [ud boolForKey:@"sv_vohandan"];
    Vars.fastfire       = [ud boolForKey:@"sv_fastfire"];
    doublegun           = [ud boolForKey:@"sv_doublegun"];
    resetguest          = [ud boolForKey:@"sv_resetguest"];
    // ✅ Đã xoá: fmedkit, highfps120
    NoRecoilEnabled       = [ud boolForKey:@"sv_NoRecoil"];
    if (NoRecoilEnabled) [self toggleNoRecoil:YES];

    SpeedX50Enabled = [ud boolForKey:@"sv_SpeedX50"];
    if (SpeedX50Enabled) ApplySpeedX50(YES);

    if ([ud objectForKey:@"sv_fixLoginTimeout"])
        fixLoginTimeout = [ud floatForKey:@"sv_fixLoginTimeout"];

    Vars.AutoFire = [ud boolForKey:@"sv_AutoFire"];
    g_showAutoFireButton = [ud boolForKey:@"sv_ShowAutoFireButton"];
    if (g_showAutoFireButton) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self autoFireModeUI];
        });
    }

    Vars.Underground = [ud boolForKey:@"sv_Underground"];
    g_showUnderButton = [ud boolForKey:@"sv_ShowUnderButton"];
    if (g_showUnderButton) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self underModeUI];
        });
    }

    if ([ud objectForKey:@"sv_espLineHue"])     espLineHue     = [ud floatForKey:@"sv_espLineHue"];
    if ([ud objectForKey:@"sv_espBoxHue"])      espBoxHue      = [ud floatForKey:@"sv_espBoxHue"];
    if ([ud objectForKey:@"sv_espSkeletonHue"]) espSkeletonHue = [ud floatForKey:@"sv_espSkeletonHue"];
    if ([ud objectForKey:@"sv_espFovHue"])      espFovHue      = [ud floatForKey:@"sv_espFovHue"];

    if ([ud objectForKey:@"sv_MenuColorTheme"])  MenuColorTheme  = (int)[ud integerForKey:@"sv_MenuColorTheme"];
    if ([ud objectForKey:@"sv_menuCornerStyle"]) menuCornerStyle = (int)[ud integerForKey:@"sv_menuCornerStyle"];
    if ([ud objectForKey:@"sv_isDarkMode"])      isDarkMode      = [ud boolForKey:@"sv_isDarkMode"];
    if ([ud objectForKey:@"sv_isStreamProof"])   isStreamProof   = [ud boolForKey:@"sv_isStreamProof"];
    if ([ud objectForKey:@"sv_menuAlpha"])       menuAlpha       = [ud floatForKey:@"sv_menuAlpha"];
    if ([ud objectForKey:@"sv_menuScale"])       menuScale       = [ud floatForKey:@"sv_menuScale"];
}

#pragma mark - Build Save UI
- (CGFloat)buildSaveUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    y = [self addSectionLabel:[self loc:DSTR("language_title")] atY:y width:w padding:p];

    NSArray *langNames  = [ImGuiDrawView supportedLangNames];
    NSArray *langCodes  = [ImGuiDrawView supportedLangCodes];
    NSString *curLang   = [[NSUserDefaults standardUserDefaults] stringForKey:@"vntool_lang"] ?: @"vi";
    NSInteger cols = 2;
    CGFloat gap = 8;
    CGFloat btnW = (w - gap * (cols - 1)) / (CGFloat)cols;
    CGFloat btnH = 40;
    for (NSInteger i = 0; i < (NSInteger)langCodes.count; i++) {
        NSInteger row = i / cols;
        NSInteger col = i % cols;
        BOOL selected = [curLang isEqualToString:langCodes[i]];
        UIButton *lb  = [[UIButton alloc] initWithFrame:
            CGRectMake(p + col*(btnW+gap), y + row*(btnH+gap), btnW, btnH)];
        lb.backgroundColor    = [self pillColor];
        lb.layer.cornerRadius = 10.0f;
        lb.layer.borderWidth  = selected ? 1.5 : 0.5;
        lb.layer.borderColor  = selected
            ? [[self accentColor] colorWithAlphaComponent:0.55].CGColor
            : [[self secondaryTextColor] colorWithAlphaComponent:0.15].CGColor;
        [lb setTitle:langNames[i] forState:UIControlStateNormal];
        lb.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        [lb setTitleColor:selected ? [self accentColor] : [self textColor] forState:UIControlStateNormal];
        lb.tag = i;
        [lb addTarget:self action:@selector(langBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentContainer addSubview:lb];
    }
    NSInteger rows = ((NSInteger)langCodes.count + cols - 1) / cols;
    y += rows * (btnH + gap) + 6;

    y = [self addSectionLabel:[self loc:DSTR("save_title")] atY:y width:w padding:p];

    UILabel *saveDesc = [[UILabel alloc] initWithFrame:CGRectMake(p, y, w, 0)];
    saveDesc.text          = [self loc:DSTR("save_desc")];
    saveDesc.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    saveDesc.textColor     = [[self textColor] colorWithAlphaComponent:0.65];
    saveDesc.numberOfLines = 0;
    CGSize sz1 = [saveDesc sizeThatFits:CGSizeMake(w, MAXFLOAT)];
    saveDesc.frame = CGRectMake(p, y, w, sz1.height);
    [self.contentContainer addSubview:saveDesc];
    y += sz1.height + 10;

    UIButton *saveBtn = [[UIButton alloc] initWithFrame:CGRectMake(p, y, w, 44)];
    saveBtn.backgroundColor   = [self pillColor];
    saveBtn.layer.cornerRadius = 12.0f;
    saveBtn.layer.borderWidth  = 1.0;
    saveBtn.layer.borderColor  = [[self accentColor] colorWithAlphaComponent:0.4].CGColor;
    [saveBtn setTitle:[self loc:DSTR("save_btn")] forState:UIControlStateNormal];
    [saveBtn setTitleColor:[self accentColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [saveBtn addTarget:self action:@selector(saveSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.contentContainer addSubview:saveBtn];
    y += 44 + 10;

    y = [self addSectionLabel:[self loc:DSTR("delete_title")] atY:y width:w padding:p];

    UILabel *delDesc = [[UILabel alloc] initWithFrame:CGRectMake(p, y, w, 0)];
    delDesc.text          = [self loc:DSTR("delete_desc")];
    delDesc.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    delDesc.textColor     = [[self textColor] colorWithAlphaComponent:0.65];
    delDesc.numberOfLines = 0;
    CGSize sz2 = [delDesc sizeThatFits:CGSizeMake(w, MAXFLOAT)];
    delDesc.frame = CGRectMake(p, y, w, sz2.height);
    [self.contentContainer addSubview:delDesc];
    y += sz2.height + 10;

    UIButton *delBtn = [[UIButton alloc] initWithFrame:CGRectMake(p, y, w, 44)];
    delBtn.backgroundColor   = [self pillColor];
    delBtn.layer.cornerRadius = 12.0f;
    delBtn.layer.borderWidth  = 1.0;
    delBtn.layer.borderColor  = [UIColor colorWithRed:0.945 green:0.271 blue:0.271 alpha:0.4].CGColor;
    [delBtn setTitle:[self loc:DSTR("delete_btn")] forState:UIControlStateNormal];
    [delBtn setTitleColor:[UIColor colorWithRed:0.945 green:0.271 blue:0.271 alpha:1.0] forState:UIControlStateNormal];
    delBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [delBtn addTarget:self action:@selector(deleteSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.contentContainer addSubview:delBtn];
    y += 44 + 10;

    UILabel *statusLbl = [[UILabel alloc] initWithFrame:CGRectMake(p, y, w, 22)];
    statusLbl.textAlignment = NSTextAlignmentCenter;
    statusLbl.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    statusLbl.textColor     = [self accentColor];
    statusLbl.tag           = 9901;
    [self.contentContainer addSubview:statusLbl];
    y += 28;

    return y;
}

- (NSString *)loc:(NSString *)key {
    NSString *lang = [[NSUserDefaults standardUserDefaults] stringForKey:DSTR("vntool_lang")] ?: @"vi";
    static NSDictionary *all = nil;
    if (!all) {
    all = @{
    @"vi": @{
        @"tab_aimbot":DSTR("AIMBOT"), @"tab_esp":DSTR("HIỂN THỊ"), @"tab_misc":DSTR("KHÁC"),
        @"tab_settings":DSTR("CÀI ĐẶT"), @"tab_profile":DSTR("TÀI KHOẢN"), @"tab_save":DSTR("LƯU"),
        @"language_title":DSTR("Ngôn Ngữ"),
        @"save_title":DSTR("Lưu Setting"),
        @"save_desc":DSTR("Bật các chức năng bạn muốn rồi nhấn Lưu. Lần sau mở lại sẽ tự bật."),
        @"save_btn":DSTR("Lưu Setting Hiện Tại"),
        @"delete_title":DSTR("Xóa Setting"),
        @"delete_desc":DSTR("Xóa toàn bộ setting đã lưu, về mặc định ban đầu."),
        @"delete_btn":DSTR("Xóa Tất Cả Setting"),
        @"saved_ok":DSTR("✓ Đã lưu setting!"),
        @"deleted_ok":DSTR("✓ Đã xóa setting!"),
        @"ab_enable":DSTR("Bật Aimbot"),
        @"ab_nowall":DSTR("Không Aim Sau Tường"), @"ab_visible":DSTR("Kiểm Tra Địch"),
        @"ab_ignoreknocked":DSTR("Bỏ qua địch gục"),
        @"ab_silent":DSTR("Đạn Đuổi"),
        @"ab_cfg":DSTR("Cấu hình ngắm"), @"ab_when":DSTR("Khi nào ngắm"),
        @"ab_hitbox":DSTR("Vị trí ngắm"), @"ab_mode":DSTR("Chế độ ngắm"),
        @"ab_fov":DSTR("Bán kính FOV"), @"ab_fovcolor":DSTR("Màu FOV"),
        @"ab_speed":DSTR("Tốc độ ngắm"), @"ab_aimspeed":DSTR("Aim Speed"),
        @"ab_random":DSTR("Aimbot Random"), @"ab_random_mode":DSTR("Tỉ lệ aim đầu"),
        @"esp_enable":DSTR("Bật ESP"), @"esp_dist_title":DSTR("Khoảng Cách ESP"),
        @"esp_dist":DSTR("Khoảng cách (m)"), @"esp_lines":DSTR("Esp Dây"), @"esp_linecolor":DSTR("Màu Dây"),
        @"esp_box":DSTR("Esp Hộp"), @"esp_boxcolor":DSTR("Màu Hộp"),
        @"esp_name":DSTR("Esp Tên"), @"esp_health":DSTR("Esp Máu"),
        @"esp_skel":DSTR("Esp Xương"), @"esp_skelcolor":DSTR("Màu Xương"),
        @"esp_distshow":DSTR("Esp Khoảng cách"), @"esp_circle":DSTR("Esp Vòng tròn 3D"),
        @"esp_count":DSTR("Esp Đếm địch"), @"esp_count_lang":DSTR("Ngôn ngữ đếm địch"),
        @"misc_other":DSTR("Chức năng khác"), @"misc_logindelay":DSTR("Độ trễ đăng nhập (s)"),
        @"misc_fixlogin":DSTR("Sửa lỗi đăng nhập"), @"misc_camxa":DSTR("Cam xa"), @"misc_camxa_on":DSTR("CamXa"),
        @"misc_camxa_w":DSTR("Độ Rộng Của Cam"),
        @"misc_spin":DSTR("Xoay Người Chơi"), @"misc_spinspeed":DSTR("Tốc độ xoay"),
        @"misc_air":DSTR("Kéo Địch"), @"misc_telekill":DSTR("Kéo Địch Lại Gần"), @"misc_noreload":DSTR("Bất Tử Đạn"),
        @"misc_voanma":DSTR("Vô Hạn Đạn"), @"misc_speedx50":DSTR("Chạy Nhanh X50"), @"misc_speedbp":DSTR("Bắn Nhanh "),
        @"misc_norecoil":DSTR("Đạn Thẳng"), @"misc_Nangdich":DSTR("Nâng Địch Lên Cao"),
        @"misc_doublegun":DSTR("2 Súng"),
        @"misc_fmedkit":DSTR("Quấn Máu Nhanh"),
        @"misc_highfps120":DSTR("Ép 120 Fps"),
        @"misc_autofire":DSTR("Auto Fire"), @"misc_autofire_on":DSTR("Tự Động Bắn"),
        @"misc_autofire_delay":DSTR("Delay bắn (ms)"),
        @"set_color":DSTR("MÀU CHỦ ĐẠO"),
        @"set_color_red":DSTR("Đỏ"), @"set_color_blue":DSTR("Xanh dương"),
        @"set_color_green":DSTR("Xanh lá"), @"set_color_pink":DSTR("Hồng"),
        @"set_style":DSTR("KIỂU DÁNG MENU"), @"set_style_round":DSTR("Bo tròn"), @"set_style_square":DSTR("Vuông góc"),
        @"set_ui":DSTR("TÙY CHỈNH GIAO DIỆN"), @"set_dark":DSTR("Chế độ tối"),
        @"set_stream":DSTR("Stream Mode"),
        @"set_alpha":DSTR("Độ trong suốt menu"), @"set_scale":DSTR("Kích thước menu"),
        @"set_sys":DSTR("HỆ THỐNG"), @"set_reset":DSTR("Khôi phục cài đặt gốc"),
        @"set_resetguest":DSTR("Reset Acc Khách"),
        @"pf_title":DSTR("TÀI KHOẢN"), @"pf_feedback":DSTR("Phản hồi (Telegram)"), @"pf_logout":DSTR("Đăng xuất"),
        @"pf_plan":DSTR("Gói hiện tại của bạn là "), @"pf_plan_value":DSTR("Pro"),
        @"pf_dev":DSTR("Hack do  Vn Tool phát triển "), @"pf_owner":DSTR("Owner @tanhdz1602"),
        @"pf_for_game":DSTR(" dành cho phiên bản game "), @"pf_version":DSTR("FF TH."),
        @"pf_other_devs":DSTR("Một số dev khác "),
        @"credit_text":DSTR("Hack do Vn Tool phát triển. Cảm ơn đã sử dụng phiên bản này."),
        @"pf_key_forever":DSTR("Vĩnh viễn"),
        @"pf_key_unknown":DSTR("Không rõ"),
        @"pf_key_expired":DSTR("Đã hết hạn"),
        @"pf_key_days":DSTR("ngày"),
    },
    @"en": @{
        @"tab_aimbot":DSTR("AIMBOT"), @"tab_esp":DSTR("ESP"), @"tab_misc":DSTR("MISC"),
        @"tab_settings":DSTR("SETTINGS"), @"tab_profile":DSTR("ACCOUNT"), @"tab_save":DSTR("SAVE"),
        @"language_title":DSTR("Language"),
        @"save_title":DSTR("Save Settings"),
        @"save_desc":DSTR("Enable the features you want, then tap Save. They'll be on next time you open."),
        @"save_btn":DSTR("Save Current Settings"),
        @"delete_title":DSTR("Delete Settings"),
        @"delete_desc":DSTR("Delete all saved settings and reset to default."),
        @"delete_btn":DSTR("Delete All Settings"),
        @"saved_ok":DSTR("✓ Settings saved!"),
        @"deleted_ok":DSTR("✓ Settings deleted!"),
        @"ab_enable":DSTR("Enable Aimbot"),
        @"ab_nowall":DSTR("No Aim Through Walls"), @"ab_visible":DSTR("Visibility Check"),
        @"ab_ignoreknocked":DSTR("Ignore Knocked"),
        @"ab_silent":DSTR("Silent Aim"),
        @"ab_cfg":DSTR("Aim Config"), @"ab_when":DSTR("Aim When"),
        @"ab_hitbox":DSTR("Aim Hitbox"), @"ab_mode":DSTR("Aim Mode"),
        @"ab_fov":DSTR("FOV Radius"), @"ab_fovcolor":DSTR("FOV Color"),
        @"ab_speed":DSTR("Aim Speed"), @"ab_aimspeed":DSTR("Aim Speed"),
        @"ab_random":DSTR("Aimbot Random"), @"ab_random_mode":DSTR("Headshot Rate"),
        @"esp_enable":DSTR("Enable ESP"), @"esp_dist_title":DSTR("ESP Distance"),
        @"esp_dist":DSTR("Distance (m)"), @"esp_lines":DSTR("ESP Lines"), @"esp_linecolor":DSTR("Line Color"),
        @"esp_box":DSTR("ESP Box"), @"esp_boxcolor":DSTR("Box Color"),
        @"esp_name":DSTR("ESP Name"), @"esp_health":DSTR("ESP Health"),
        @"esp_skel":DSTR("ESP Skeleton"), @"esp_skelcolor":DSTR("Skeleton Color"),
        @"esp_distshow":DSTR("ESP Distance"), @"esp_circle":DSTR("3D Circle"),
        @"esp_count":DSTR("Enemy Count"), @"esp_count_lang":DSTR("Enemy Count Language"),
        @"misc_other":DSTR("Other"), @"misc_logindelay":DSTR("Login Delay (s)"),
        @"misc_fixlogin":DSTR("Fix Login"), @"misc_camxa":DSTR("Far Cam"), @"misc_camxa_on":DSTR("Far Cam"),
        @"misc_camxa_w":DSTR("Cam Width"),
        @"misc_spin":DSTR("Spin Player"), @"misc_spinspeed":DSTR("Spin Speed"),
        @"misc_air":DSTR("Pull Enemy"),  @"misc_noreload":DSTR("No Reload"),
        @"misc_voanma":DSTR("Infinite Ammo"), @"misc_speedx50":DSTR("Speed x50"), @"misc_telekill":DSTR("Tele Kill"),  @"misc_speedbp":DSTR("brutal "),
        @"misc_norecoil":DSTR("No Recoil"), @"misc_Nangdich":DSTR("Up player"),
        @"misc_doublegun":DSTR("2 Gun"),
        @"misc_fmedkit":DSTR("FastMedkit"),
        @"misc_highfps120":DSTR("HighFPS120"),
        @"misc_autofire":DSTR("Auto Fire"), @"misc_autofire_on":DSTR("Auto Fire"),
        @"misc_autofire_delay":DSTR("Fire Delay (ms)"),
        @"set_color":DSTR("PRIMARY COLOR"),
        @"set_color_red":DSTR("Red"), @"set_color_blue":DSTR("Blue"),
        @"set_color_green":DSTR("Green"), @"set_color_pink":DSTR("Pink"),
        @"set_style":DSTR("MENU STYLE"), @"set_style_round":DSTR("Rounded"), @"set_style_square":DSTR("Square"),
        @"set_ui":DSTR("UI CUSTOMIZATION"), @"set_dark":DSTR("Dark Mode"),
        @"set_stream":DSTR("Stream Mode"),
        @"set_alpha":DSTR("Menu Opacity"), @"set_scale":DSTR("Menu Size"),
        @"set_sys":DSTR("SYSTEM"), @"set_reset":DSTR("Restore Defaults"),
        @"set_resetguest":DSTR("Reset Guest "),
        @"pf_title":DSTR("ACCOUNT"), @"pf_feedback":DSTR("Feedback (Telegram)"), @"pf_logout":DSTR("Logout"),
        @"pf_plan":DSTR("Your current plan is "), @"pf_plan_value":DSTR("Pro"),
        @"pf_dev":DSTR("Hack developed by Vn Tool "), @"pf_owner":DSTR("Owner @tanhdz1602"),
        @"pf_for_game":DSTR(" for game version "), @"pf_version":DSTR("FF TH."),
        @"pf_other_devs":DSTR("Other devs "),
        @"credit_text":DSTR("Hack developed by Vn Tool . Thanks for using this version."),
        @"pf_key_forever":DSTR("Forever"),
        @"pf_key_unknown":DSTR("Unknown"),
        @"pf_key_expired":DSTR("Expired"),
        @"pf_key_days":DSTR("days"),
    },
    };
    }
    NSDictionary *dict = all[lang] ?: all[@"vi"];
    return dict[key] ?: (all[@"vi"][key] ?: key);
}

+ (NSArray<NSString *> *)supportedLangCodes  { return @[@"vi",@"en"]; }
+ (NSArray<NSString *> *)supportedLangNames {
    return @[@"Tiếng Việt",@"English"];
}

- (void)langBtnTapped:(UIButton *)sender {
    NSArray *codes = [ImGuiDrawView supportedLangCodes];
    if (sender.tag < (NSInteger)codes.count) {
        [[NSUserDefaults standardUserDefaults] setObject:codes[sender.tag] forKey:@"vntool_lang"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self updateSidebarForTab:self.currentTab];
        [self loadTabContent:self.currentTab];
    }
}

- (void)saveSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:YES forKey:@"sv_marker"];

    [ud setBool:Vars.Aimbot          forKey:@"sv_Aimbot"];
    [ud setBool:Vars.AimKillSend     forKey:@"sv_AimKillSend"];
    [ud setBool:Vars.VisibleCheck    forKey:@"sv_VisibleCheck"];
    [ud setBool:Vars.IgnoreKnocked   forKey:@"sv_IgnoreKnocked"];
    [ud setFloat:Vars.AimFov         forKey:@"sv_AimFov"];
    [ud setFloat:Vars.AimSpeed       forKey:@"sv_AimSpeed"];
    [ud setInteger:Vars.AimHitbox    forKey:@"sv_AimHitbox"];
    [ud setInteger:Vars.AimMode      forKey:@"sv_AimMode"];
    [ud setInteger:Vars.AimWhen      forKey:@"sv_AimWhen"];
    [ud setBool:Vars.AimRandomEnable forKey:@"sv_AimRandom"];
    [ud setInteger:Vars.AimRandomMode forKey:@"sv_AimRandomMode"];
    [ud setBool:Vars.SilentAim     forKey:@"sv_SilentAim"];
    [ud setFloat:Vars.SilentFov    forKey:@"sv_SilentFov"];

    [ud setBool:Vars.Enable          forKey:@"sv_Enable"];
    [ud setBool:Vars.Box             forKey:@"sv_Box"];
    [ud setBool:Vars.lines           forKey:@"sv_lines"];
    [ud setBool:Vars.Health          forKey:@"sv_Health"];
    [ud setBool:Vars.Name            forKey:@"sv_Name"];
    [ud setBool:Vars.skeleton        forKey:@"sv_skeleton"];
    [ud setBool:Vars.Distance        forKey:@"sv_Distance"];
    [ud setBool:Vars.circlepos       forKey:@"sv_circlepos"];
    [ud setBool:Vars.enemycount      forKey:@"sv_enemycount"];
    [ud setFloat:Vars.espDrawDistance forKey:@"sv_espDrawDistance"];

    [ud setBool:Vars.SpinBotEnabled  forKey:@"sv_SpinBot"];
    [ud setFloat:Vars.SpinBotSpeed   forKey:@"sv_SpinSpeed"];
    [ud setBool:Vars.AutoFire        forKey:@"sv_AutoFire"];
    [ud setBool:g_showAutoFireButton forKey:@"sv_ShowAutoFireButton"];
    [ud setFloat:Vars.AutoFireDelay  forKey:@"sv_AutoFireDelay"];
    [ud setBool:Vars.camxa           forKey:@"sv_camxa"];
    [ud setFloat:Vars.CamXaValue     forKey:@"sv_CamXaValue"];
    [ud setBool:Vars.AIRPlayer       forKey:@"sv_AIRPlayer"];
    [ud setBool:Vars.telekill        forKey:@"sv_telekill"];
    [ud setBool:Vars.Nangdich        forKey:@"sv_Nangdich"];
    [ud setBool:Vars.noreload        forKey:@"sv_noreload"];
    [ud setBool:Vars.vohandan        forKey:@"sv_vohandan"];
    [ud setBool:Vars.fastfire        forKey:@"sv_fastfire"];
    [ud setBool:doublegun            forKey:@"sv_doublegun"];
    [ud setBool:resetguest           forKey:@"sv_resetguest"];
    // ✅ Đã xoá: sv_fmedkit, sv_highfps120
    [ud setBool:NoRecoilEnabled      forKey:@"sv_NoRecoil"];

    [ud setBool:SpeedX50Enabled      forKey:@"sv_SpeedX50"];

    [ud setBool:g_showUnderButton    forKey:@"sv_ShowUnderButton"];
    [ud setBool:Vars.Underground     forKey:@"sv_Underground"];

    [ud setFloat:fixLoginTimeout     forKey:@"sv_fixLoginTimeout"];

    [ud setFloat:espLineHue          forKey:@"sv_espLineHue"];
    [ud setFloat:espBoxHue           forKey:@"sv_espBoxHue"];
    [ud setFloat:espSkeletonHue      forKey:@"sv_espSkeletonHue"];
    [ud setFloat:espFovHue           forKey:@"sv_espFovHue"];

    [ud setInteger:MenuColorTheme    forKey:@"sv_MenuColorTheme"];
    [ud setInteger:menuCornerStyle   forKey:@"sv_menuCornerStyle"];
    [ud setBool:isDarkMode           forKey:@"sv_isDarkMode"];
    [ud setBool:isStreamProof        forKey:@"sv_isStreamProof"];
    [ud setFloat:menuAlpha           forKey:@"sv_menuAlpha"];
    [ud setFloat:menuScale           forKey:@"sv_menuScale"];
    [ud synchronize];

    NSString *espLang2 = [ud stringForKey:@"vntool_esp_lang"]
                         ?: ([ud stringForKey:@"vntool_lang"] ?: @"vi");
    extern int g_espLang;
    g_espLang = [espLang2 isEqualToString:@"vi"] ? 1 : 0;

    UILabel *lbl = (UILabel *)[self.contentContainer viewWithTag:9901];
    lbl.text = [self loc:DSTR("saved_ok")];
    [UIView animateWithDuration:2.0 delay:1.5 options:0 animations:^{
        lbl.alpha = 0;
    } completion:^(BOOL f){ lbl.alpha = 1; lbl.text = DSTR(""); }];
}

- (void)deleteSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSArray *keys = @[@"sv_marker",
                      @"sv_Aimbot",@"sv_AimKillSend",@"sv_VisibleCheck",
                      @"sv_IgnoreKnocked",@"sv_Enable",@"sv_Box",@"sv_lines",@"sv_Health",
                      @"sv_Name",@"sv_skeleton",@"sv_Distance",@"sv_circlepos",@"sv_enemycount",
                      @"sv_espDrawDistance",@"sv_SpinBot",@"sv_AutoFire",@"sv_AutoFireDelay",
                      @"sv_ShowAutoFireButton",
                      @"sv_ShowUnderButton", @"sv_Underground",
                      @"sv_camxa",@"sv_AIRPlayer",@"sv_noreload",@"sv_vohandan",@"sv_fastfire",
                      @"sv_doublegun",
                      @"sv_resetguest",
                      // ✅ Đã xoá: sv_fmedkit, sv_highfps120
                      @"sv_NoRecoil", @"sv_Nangdich", @"sv_telekill",
                      @"sv_SpeedX50",
                      @"sv_fixLoginTimeout",
                      @"sv_AimFov",@"sv_AimSpeed",@"sv_SpinSpeed",@"sv_CamXaValue",
                      @"sv_AimHitbox",@"sv_AimMode",@"sv_AimWhen",@"sv_AimRandom",@"sv_AimRandomMode",
                      @"sv_SilentAim",@"sv_SilentFov",
                      @"sv_espLineHue",@"sv_espBoxHue",@"sv_espSkeletonHue",@"sv_espFovHue",
                      @"sv_MenuColorTheme",@"sv_menuCornerStyle",@"sv_isDarkMode",
                      @"sv_isStreamProof",@"sv_menuAlpha",@"sv_menuScale"];
    for (NSString *k in keys) [ud removeObjectForKey:k];
    [ud synchronize];

    UILabel *lbl = (UILabel *)[self.contentContainer viewWithTag:9901];
    lbl.text = [self loc:DSTR("deleted_ok")];
    [UIView animateWithDuration:2.0 delay:1.5 options:0 animations:^{
        lbl.alpha = 0;
    } completion:^(BOOL f){ lbl.alpha = 1; lbl.text = DSTR(""); }];
}

- (void)setKeyExpiryDateFromISO:(NSString *)isoStr {
    if (!isoStr.length) return;
    self.keyExpiresAt = isoStr;
    NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
    fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *d = [fmt dateFromString:isoStr];
    if (!d) {
        fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        d = [fmt dateFromString:isoStr];
    }
    self.keyExpiryDate = d;
}

- (NSString *)keyRemainingString {
    if (!self.keyExpiryDate) {
        return [NSString stringWithFormat:@"%@ / %@",
                [self loc:DSTR("pf_key_forever")], [self loc:DSTR("pf_key_unknown")]];
    }
    NSTimeInterval sec = [self.keyExpiryDate timeIntervalSinceNow];
    if (sec <= 0) return [self loc:DSTR("pf_key_expired")];
    long days  = (long)(sec / 86400);
    long hours = (long)((sec - days*86400) / 3600);
    long mins  = (long)((sec - days*86400 - hours*3600) / 60);
    long secs  = (long)(sec) % 60;
    if (days > 0)
        return [NSString stringWithFormat:@"%ld %@ %02ld:%02ld:%02ld",
                days, [self loc:DSTR("pf_key_days")], hours, mins, secs];
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", hours, mins, secs];
}

- (void)startKeyCountdown {
    [self.keyCountdownTimer invalidate];
    self.keyCountdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
        target:self selector:@selector(tickKeyCountdown) userInfo:nil repeats:YES];
}

- (void)tickKeyCountdown {
    if (self.currentTab != MenuTabProfile) return;
    UILabel *lbl = (UILabel *)[self.contentContainer viewWithTag:7001];
    if (lbl) lbl.text = [self keyRemainingString];
}

#pragma mark - Build Credit
- (CGFloat)addCreditText:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    return y;
}

#pragma mark - Build Aimbot UI
- (CGFloat)buildAimbotUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("ab_enable")] sub:@"Bật aim tự động" key:@"Aimbot" value:Vars.Aimbot]
                       right:[self mkDict:[self loc:DSTR("ab_silent")] sub:@"Silent Aim" key:@"SilentAim" value:Vars.SilentAim]
                         atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("ab_visible")] sub:@"Chỉ aim khi thấy" key:@"VisibleCheck" value:Vars.VisibleCheck]
                       right:[self mkDict:[self loc:DSTR("ab_ignoreknocked")] sub:@"Bỏ qua địch gục" key:@"IgnoreKnocked" value:Vars.IgnoreKnocked]
                         atY:y width:w padding:p];

    y = [self addSectionLabel:@"Aimkill Send" atY:y width:w padding:p];
    y = [self addTwoColsLeft:[self mkDict:@"AimKill 360 " sub:@"Không Nên Sử Dụng Acc Chính" key:@"AimKillSend" value:Vars.AimKillSend]
                       right:[self mkDict:@"" sub:@"" key:@"_emptyAimKill" value:NO]
                         atY:y width:w padding:p];

    y = [self addSectionLabel:[self loc:DSTR("ab_cfg")] atY:y width:w padding:p];
    y = [self addComboRow:[self loc:DSTR("ab_when")] options:@[@(0),@(1),@(2),@(3)] optionNames:Vars.dir selectedIdx:Vars.AimWhen tag:3001 atY:y width:w padding:p];
    y = [self addComboRow:[self loc:DSTR("ab_hitbox")] options:@[@(0),@(1),@(2)] optionNames:Vars.aimHitboxes selectedIdx:Vars.AimHitbox tag:3002 atY:y width:w padding:p];
    y = [self addComboRow:[self loc:DSTR("ab_mode")] options:@[@(0),@(1),@(2)] optionNames:Vars.aimModes selectedIdx:Vars.AimMode tag:3003 atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("ab_random")] sub:@"Random aim" key:@"AimRandom" value:Vars.AimRandomEnable]
                       right:[self mkDict:@"" sub:@"" key:@"_empty1" value:NO]
                         atY:y width:w padding:p];
    if (Vars.AimRandomEnable) {
        y = [self addComboRow:[self loc:DSTR("ab_random_mode")] options:@[@(0),@(1),@(2)] optionNames:Vars.aimRandomModes selectedIdx:Vars.AimRandomMode tag:3005 atY:y width:w padding:p];
    }

    y = [self addSectionLabel:[self loc:DSTR("ab_fov")] atY:y width:w padding:p];
    y = [self addSliderPill:DSTR("FOV") value:Vars.AimFov min:0 max:360 selector:@selector(sliderFovChanged:) atY:y width:w padding:p];
    y = [self addHueSlider:[self loc:DSTR("ab_fovcolor")] tag:8004 hue:espFovHue atY:y width:w padding:p];

    y = [self addSectionLabel:[self loc:DSTR("ab_speed")] atY:y width:w padding:p];
    y = [self addSliderPill:[self loc:DSTR("ab_aimspeed")] value:Vars.AimSpeed min:1 max:100 selector:@selector(sliderSpeedChanged:) atY:y width:w padding:p];

    return y;
}

#pragma mark - Build ESP UI
- (CGFloat)buildEspUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("esp_enable")] sub:@"Bật hiển thị" key:@"Enable" value:Vars.Enable]
                       right:[self mkDict:@"" sub:@"" key:@"_empty2" value:NO]
                         atY:y width:w padding:p];

    y = [self addSectionLabel:[self loc:DSTR("esp_dist_title")] atY:y width:w padding:p];
    y = [self addSliderPill:[self loc:DSTR("esp_dist")] value:Vars.espDrawDistance min:100 max:500 selector:@selector(sliderESPDistanceChanged:) atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("esp_lines")] sub:@"Đường kẻ" key:@"lines" value:Vars.lines]
                       right:[self mkDict:[self loc:DSTR("esp_box")] sub:@"Hộp vuông" key:@"Box" value:Vars.Box]
                         atY:y width:w padding:p];

    if (Vars.lines)
        y = [self addHueSlider:[self loc:DSTR("esp_linecolor")] tag:8001 hue:espLineHue atY:y width:w padding:p];
    if (Vars.Box)
        y = [self addHueSlider:[self loc:DSTR("esp_boxcolor")] tag:8002 hue:espBoxHue atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("esp_name")] sub:@"Tên địch" key:@"Name" value:Vars.Name]
                       right:[self mkDict:[self loc:DSTR("esp_health")] sub:@"Thanh máu" key:@"Health" value:Vars.Health]
                         atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("esp_skel")] sub:@"Khung xương" key:@"skeleton" value:Vars.skeleton]
                       right:[self mkDict:[self loc:DSTR("esp_distshow")] sub:@"Số mét" key:@"Distance" value:Vars.Distance]
                         atY:y width:w padding:p];

    if (Vars.skeleton)
        y = [self addHueSlider:[self loc:DSTR("esp_skelcolor")] tag:8003 hue:espSkeletonHue atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("esp_count")] sub:@"Đếm địch" key:@"enemycount" value:Vars.enemycount]
                       right:[self mkDict:@"" sub:@"" key:@"_empty3" value:NO]
                         atY:y width:w padding:p];

    if (Vars.enemycount) {
        static const char *espCountLangs[2] = {"Tiếng Việt", "English"};
        NSString *curEspLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"vntool_esp_lang"]
                               ?: ([[NSUserDefaults standardUserDefaults] stringForKey:@"vntool_lang"] ?: @"vi");
        int sel = [curEspLang isEqualToString:@"vi"] ? 0 : 1;
        y = [self addComboRow:[self loc:DSTR("esp_count_lang")] options:@[@(0),@(1)] optionNames:espCountLangs selectedIdx:sel tag:3004 atY:y width:w padding:p];
    }

    return y;
}

#pragma mark - Build Misc UI
- (CGFloat)buildMiscUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    y = [self addSectionLabel:[self loc:DSTR("misc_other")] atY:y width:w padding:p];

    y = [self addSliderPill:[self loc:DSTR("misc_logindelay")] value:fixLoginTimeout min:40 max:80 selector:@selector(sliderDelayChanged:) atY:y width:w padding:p];
    y = [self addButtonPill:[self loc:DSTR("misc_fixlogin")] selector:@selector(fixLoginTapped) atY:y width:w padding:p];

    y = [self addSectionLabel:[self loc:DSTR("misc_camxa")] atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_camxa_on")] sub:@"Cam xa" key:@"CamXa" value:Vars.camxa]
                       right:[self mkDict:[self loc:DSTR("misc_spin")] sub:@"Xoay người" key:@"SpinBotEnabled" value:Vars.SpinBotEnabled]
                         atY:y width:w padding:p];

    if (Vars.camxa) {
        y = [self addSliderPill:[self loc:DSTR("misc_camxa_w")] value:Vars.CamXaValue min:10 max:180 selector:@selector(sliderCamXaChanged:) atY:y width:w padding:p];
    }
    if (Vars.SpinBotEnabled) {
        y = [self addSliderPill:[self loc:DSTR("misc_spinspeed")] value:Vars.SpinBotSpeed min:0.1 max:50 selector:@selector(sliderSpinBotSpeedChanged:) atY:y width:w padding:p];
    }

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_air")] sub:@"Kéo địch" key:@"AIRPlayer" value:Vars.AIRPlayer]
                       right:[self mkDict:[self loc:DSTR("misc_noreload")] sub:@"Bất tử đạn" key:@"noreload" value:Vars.noreload]
                         atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_voanma")] sub:@"Vô hạn đạn" key:@"vohandan" value:Vars.vohandan]
                       right:[self mkDict:[self loc:DSTR("misc_speedbp")] sub:@"Bắn nhanh" key:@"fastfire" value:Vars.fastfire]
                         atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_norecoil")] sub:@"Đạn thẳng" key:@"NoRecoil" value:NoRecoilEnabled]
                       right:[self mkDict:[self loc:DSTR("misc_Nangdich")] sub:@"Nâng địch" key:@"Nangdich" value:Vars.Nangdich]
                         atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_doublegun")] sub:@"Double Gun" key:@"doublegun" value:doublegun]
                       right:[self mkDict:[self loc:DSTR("misc_telekill")] sub:@"Kéo địch gần" key:@"telekill" value:Vars.telekill]
                         atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_speedx50")] sub:@"Chạy nhanh x50" key:@"SpeedX50" value:SpeedX50Enabled]
                       right:[self mkDict:@"" sub:@"" key:@"_emptySpeed" value:NO]
                         atY:y width:w padding:p];

    y = [self addSectionLabel:[self loc:DSTR("misc_autofire")] atY:y width:w padding:p];
    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("misc_autofire_on")] sub:@"Tự động bắn" key:@"ShowAutoFireButton" value:g_showAutoFireButton]
                       right:[self mkDict:@"Underkill" sub:@"Bật Button" key:@"ShowUnderButton" value:g_showUnderButton]
                         atY:y width:w padding:p];
    y = [self addSliderPill:[self loc:DSTR("misc_autofire_delay")] value:Vars.AutoFireDelay * 1000.f min:1 max:300 selector:@selector(sliderAutoFireDelayChanged:) atY:y width:w padding:p];

    return y;
}

#pragma mark - Build Settings UI
- (CGFloat)buildSettingsUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    y = [self addSectionLabel:[self loc:DSTR("set_color")] atY:y width:w padding:p];

    NSArray *colors = @[[self loc:DSTR("set_color_red")], [self loc:DSTR("set_color_blue")], [self loc:DSTR("set_color_green")], [self loc:DSTR("set_color_pink")]];
    CGFloat btnW = (w - 8) / 4;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(p, y, w, 44)];
    container.backgroundColor = [self pillColor];
    container.layer.cornerRadius = 10;
    container.layer.borderWidth = 0.5;
    container.layer.borderColor = [[self secondaryTextColor] colorWithAlphaComponent:0.15].CGColor;
    [self.contentContainer addSubview:container];

    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(4 + (btnW * MenuColorTheme), 4, btnW - 8, 36)];
    indicator.backgroundColor = [self accentColor];
    indicator.layer.cornerRadius = 8;
    [container addSubview:indicator];

    for (int i=0; i<4; i++) {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(4 + (btnW * i), 4, btnW - 8, 36)];
        btn.tag = 50000 + i;
        UILabel *lbl = [[UILabel alloc] initWithFrame:btn.bounds];
        lbl.text = colors[i];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
        lbl.textColor = (i == MenuColorTheme) ? [UIColor whiteColor] : [self textColor];
        [btn addSubview:lbl];
        [btn addTarget:self action:@selector(changeMenuTheme:) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:btn];
    }
    y += 44 + 14;

    y = [self addSectionLabel:[self loc:DSTR("set_style")] atY:y width:w padding:p];

    NSArray *styles = @[[self loc:DSTR("set_style_round")], [self loc:DSTR("set_style_square")]];
    CGFloat styleBtnW = (w - 8) / 2;
    UIView *styleContainer = [[UIView alloc] initWithFrame:CGRectMake(p, y, w, 44)];
    styleContainer.backgroundColor = [self pillColor];
    styleContainer.layer.cornerRadius = 10;
    styleContainer.layer.borderWidth = 0.5;
    styleContainer.layer.borderColor = [[self secondaryTextColor] colorWithAlphaComponent:0.15].CGColor;
    [self.contentContainer addSubview:styleContainer];

    UIView *styleIndicator = [[UIView alloc] initWithFrame:CGRectMake(4 + (styleBtnW * menuCornerStyle), 4, styleBtnW - 8, 36)];
    styleIndicator.backgroundColor = [self accentColor];
    styleIndicator.layer.cornerRadius = 8;
    [styleContainer addSubview:styleIndicator];

    for (int i=0; i<2; i++) {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(4 + (styleBtnW * i), 4, styleBtnW - 8, 36)];
        btn.tag = 60000 + i;
        UILabel *lbl = [[UILabel alloc] initWithFrame:btn.bounds];
        lbl.text = styles[i];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
        lbl.textColor = (i == menuCornerStyle) ? [UIColor whiteColor] : [self textColor];
        [btn addSubview:lbl];
        [btn addTarget:self action:@selector(changeCornerStyle:) forControlEvents:UIControlEventTouchUpInside];
        [styleContainer addSubview:btn];
    }
    y += 44 + 14;

    y = [self addSectionLabel:[self loc:DSTR("set_ui")] atY:y width:w padding:p];

    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("set_dark")] sub:@"Chế độ tối" key:@"SettingsDarkMode" value:isDarkMode]
                       right:[self mkDict:[self loc:DSTR("set_stream")] sub:@"Stream Proof" key:@"StreamProof" value:isStreamProof]
                         atY:y width:w padding:p];

    y = [self addSliderPill:[self loc:DSTR("set_alpha")] value:menuAlpha * 100 min:40 max:100 selector:@selector(sliderAlphaChanged:) atY:y width:w padding:p];
    UIView *alphaPill = self.contentContainer.subviews.lastObject;
    for (UIView *sub in alphaPill.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub.frame.origin.x > w - 80) {
            ((UILabel *)sub).text = [NSString stringWithFormat:DSTR("%.0f%%"), menuAlpha * 100];
        }
    }

    y = [self addSliderPill:[self loc:DSTR("set_scale")] value:menuScale min:0.8 max:1.2 selector:@selector(sliderScaleChanged:) atY:y width:w padding:p];
    UIView *scalePill = self.contentContainer.subviews.lastObject;
    for (UIView *sub in scalePill.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub.frame.origin.x > w - 80) {
            ((UILabel *)sub).text = [NSString stringWithFormat:DSTR("%.1fx"), menuScale];
        }
    }

    y = [self addSectionLabel:[self loc:DSTR("set_sys")] atY:y width:w padding:p];
    y = [self addTwoColsLeft:[self mkDict:[self loc:DSTR("set_resetguest")] sub:@"Reset acc khách" key:@"resetguest" value:resetguest]
                       right:[self mkDict:@"" sub:@"" key:@"_empty6" value:NO]
                         atY:y width:w padding:p];
    y = [self addButtonPill:@"🔥 Hook AC" selector:@selector(runACBypass:) atY:y width:w padding:p];
    y = [self addButtonPill:[self loc:DSTR("save_btn")] selector:@selector(saveSettings) atY:y width:w padding:p];
    y = [self addButtonPill:[self loc:DSTR("set_reset")] selector:@selector(resetSettingsTapped) atY:y width:w padding:p];

    UILabel *savedStatus = [[UILabel alloc] initWithFrame:CGRectMake(p, y, w, 24)];
    savedStatus.tag = 9901;
    savedStatus.textAlignment = NSTextAlignmentCenter;
    savedStatus.textColor = [self accentColor];
    savedStatus.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.contentContainer addSubview:savedStatus];
    y += 28;

    return y;
}

#pragma mark - Build Profile UI
- (CGFloat)buildProfileUI:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    y = [self addSectionLabel:[self loc:DSTR("pf_title")] atY:y width:w padding:p];
    y += 6;

    NSMutableAttributedString *str1 = [[NSMutableAttributedString alloc] initWithString:[self loc:DSTR("pf_plan")] attributes:@{NSForegroundColorAttributeName: [self textColor]}];
    [str1 appendAttributedString:[[NSAttributedString alloc] initWithString:[self loc:DSTR("pf_plan_value")] attributes:@{NSForegroundColorAttributeName: [self accentColor], NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy]}]];

    UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(p + 4, y, w - 8, 0)];
    lbl1.numberOfLines = 0;
    lbl1.attributedText = str1;
    lbl1.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    CGSize size1 = [lbl1 sizeThatFits:CGSizeMake(w - 8, MAXFLOAT)];
    lbl1.frame = CGRectMake(p + 4, y, w - 8, size1.height);
    [self.contentContainer addSubview:lbl1];
    y += size1.height + 14;

    NSMutableAttributedString *str2 = [[NSMutableAttributedString alloc] initWithString:[self loc:DSTR("pf_dev")] attributes:@{NSForegroundColorAttributeName: [self textColor]}];
    [str2 appendAttributedString:[[NSAttributedString alloc] initWithString:[self loc:DSTR("pf_owner")] attributes:@{NSForegroundColorAttributeName: [self accentColor], NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy]}]];
    [str2 appendAttributedString:[[NSAttributedString alloc] initWithString:[self loc:DSTR("pf_for_game")] attributes:@{NSForegroundColorAttributeName: [self textColor]}]];
    [str2 appendAttributedString:[[NSAttributedString alloc] initWithString:[self loc:DSTR("pf_version")] attributes:@{NSForegroundColorAttributeName: [self accentColor], NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy]}]];

    UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(p + 4, y, w - 8, 0)];
    lbl2.numberOfLines = 0;
    lbl2.attributedText = str2;
    lbl2.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    CGSize size2 = [lbl2 sizeThatFits:CGSizeMake(w - 8, MAXFLOAT)];
    lbl2.frame = CGRectMake(p + 4, y, w - 8, size2.height);
    [self.contentContainer addSubview:lbl2];
    y += size2.height + 22;

    UIButton *btnFeedback = [[UIButton alloc] initWithFrame:CGRectMake(p, y, w, 48)];
    btnFeedback.backgroundColor = [self pillColor];
    btnFeedback.layer.cornerRadius = 10;
    btnFeedback.layer.borderWidth = 0.5;
    btnFeedback.layer.borderColor = [[self accentColor] colorWithAlphaComponent:0.4].CGColor;

    UIImageView *imgLeft1 = [[UIImageView alloc] initWithFrame:CGRectMake(14, (48-22)/2.0f, 22, 22)];
    imgLeft1.image = [[UIImage systemImageNamed:@"heart.fill"] imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]];
    imgLeft1.tintColor = [self accentColor];
    [btnFeedback addSubview:imgLeft1];

    UILabel *txtBtn1 = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, w - 92, 48)];
    txtBtn1.text = [self loc:DSTR("pf_feedback")];
    txtBtn1.textColor = [self textColor];
    txtBtn1.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [btnFeedback addSubview:txtBtn1];

    UIImageView *imgRight1 = [[UIImageView alloc] initWithFrame:CGRectMake(w - 34, (48-18)/2.0f, 18, 18)];
    imgRight1.image = [[UIImage systemImageNamed:@"paperplane.fill"] imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]];
    imgRight1.tintColor = [self textColor];
    [btnFeedback addSubview:imgRight1];

    [btnFeedback addTarget:self action:@selector(feedbackTelegramTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentContainer addSubview:btnFeedback];
    y += 48 + 10;

    UIButton *btnLogout = [[UIButton alloc] initWithFrame:CGRectMake(p, y, w, 48)];
    btnLogout.backgroundColor = [self pillColor];
    btnLogout.layer.cornerRadius = 10;
    btnLogout.layer.borderWidth = 0.5;
    btnLogout.layer.borderColor = [UIColor colorWithRed:0.945 green:0.271 blue:0.271 alpha:0.4].CGColor;

    UIImageView *imgLeft2 = [[UIImageView alloc] initWithFrame:CGRectMake(14, (48-22)/2.0f, 22, 22)];
    imgLeft2.image = [[UIImage systemImageNamed:@"rectangle.portrait.and.arrow.forward.fill"] imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]];
    imgLeft2.tintColor = [UIColor colorWithRed:0.945 green:0.271 blue:0.271 alpha:1.0];
    [btnLogout addSubview:imgLeft2];

    UILabel *txtBtn2 = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, w - 58, 48)];
    txtBtn2.text = [self loc:DSTR("pf_logout")];
    txtBtn2.textColor = [UIColor colorWithRed:0.945 green:0.271 blue:0.271 alpha:1.0];
    txtBtn2.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [btnLogout addSubview:txtBtn2];

    [btnLogout addTarget:self action:@selector(logoutTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentContainer addSubview:btnLogout];
    y += 48;

    return y;
}

#pragma mark - UI Helpers

- (NSDictionary *)mkDict:(NSString *)title sub:(NSString *)sub key:(NSString *)key value:(BOOL)val {
    return @{@"title": title ?: @"", @"sub": sub ?: @"", @"key": key ?: @"", @"value": @(val)};
}

- (CGFloat)addSectionLabel:(NSString *)text atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(p + 4, y + 6, w, 20)];
    lbl.text = text;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    lbl.textColor = [self secondaryTextColor];
    [self.contentContainer addSubview:lbl];
    return y + 30;
}

- (CGFloat)addFeaturePill:(NSString *)title sub:(NSString *)sub key:(NSString *)key value:(BOOL)val selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    const CGFloat PH = 52.0f;

    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(p, y, w, PH)];
    pill.backgroundColor = [self pillColor];
    pill.layer.cornerRadius = 12.0f;
    pill.layer.borderWidth = 0.5f;
    pill.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:0.25].CGColor;
    pill.clipsToBounds = YES;
    [self.contentContainer addSubview:pill];

    // Title label
    UILabel *lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(14.0f, 8.0f, w - 74.0f, 20.0f)];
    lblTitle.text = title;
    lblTitle.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    lblTitle.textColor = [UIColor whiteColor];
    [pill addSubview:lblTitle];

    // Subtitle label
    NSString *subText = (sub && sub.length > 0) ? sub : @"Apply In Training";
    UILabel *lblSub = [[UILabel alloc] initWithFrame:CGRectMake(14.0f, 28.0f, w - 74.0f, 16.0f)];
    lblSub.text = subText;
    lblSub.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    lblSub.textColor = [self secondaryTextColor];
    [pill addSubview:lblSub];

    // iOS style Switch button
    const CGFloat swW = 44.0f;
    const CGFloat swH = 24.0f;
    const CGFloat swX = w - swW - 14.0f;
    const CGFloat swY = (PH - swH) / 2.0f;

    UIButton *cb = [[UIButton alloc] initWithFrame:CGRectMake(swX, swY, swW, swH)];
    cb.backgroundColor = val ? [self accentColor] : [self checkboxOffColor];
    cb.layer.cornerRadius = swH / 2.0f;
    cb.clipsToBounds = YES;

    UIView *thumb = [[UIView alloc] initWithFrame:CGRectMake(val ? (swW - 18.0f - 3.0f) : 3.0f, 3.0f, 18.0f, 18.0f)];
    thumb.layer.cornerRadius = 9.0f;
    thumb.backgroundColor = val ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
    thumb.userInteractionEnabled = NO;
    thumb.tag = 777;
    [cb addSubview:thumb];

    objc_setAssociatedObject(cb, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cb, "pill", pill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cb addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [pill addSubview:cb];

    // Full card tap trigger
    UIButton *tapBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, w, PH)];
    tapBtn.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(tapBtn, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(tapBtn, "pill", pill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tapBtn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [pill insertSubview:tapBtn atIndex:0];

    self.allCheckboxes[key]  = cb;
    self.checkboxStates[key] = @(val);

    return y + PH + 8.0f;
}

- (CGFloat)addTwoColsLeft:(NSDictionary *)left right:(NSDictionary *)right atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    NSString *lKey = left[@"key"];
    NSString *rKey = right[@"key"];

    BOOL hasLeft  = lKey && lKey.length > 0 && ![lKey hasPrefix:@"_"];
    BOOL hasRight = rKey && rKey.length > 0 && ![rKey hasPrefix:@"_"];

    if (hasLeft) {
        y = [self addFeaturePill:left[@"title"] sub:left[@"sub"] key:lKey
                           value:[left[@"value"] boolValue]
                        selector:@selector(toggleVar:)
                             atY:y width:w padding:p];
    }
    if (hasRight) {
        y = [self addFeaturePill:right[@"title"] sub:right[@"sub"] key:rKey
                           value:[right[@"value"] boolValue]
                        selector:@selector(toggleVar:)
                             atY:y width:w padding:p];
    }

    return y;
}

- (CGFloat)addIconFeaturePill:(NSString *)title iconName:(NSString *)iconName key:(NSString *)key value:(BOOL)val selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    return [self addFeaturePill:title sub:@"" key:key value:val selector:sel atY:y width:w padding:p];
}

- (CGFloat)addColorRow:(NSString *)title r:(float)r g:(float)g b:(float)b tag:(int)tag atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p { return y; }
- (void)colorSwatchTapped:(UIButton *)sender {}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)vc {}
- (void)colorPickerViewController:(UIColorPickerViewController *)vc didSelectColor:(UIColor *)color continuously:(BOOL)c {}
- (void)applyColor:(float)r g:(float)g b:(float)b toTag:(int)tag swatch:(UIButton *)btn {}

- (CGFloat)addHueSlider:(NSString *)title tag:(int)tag hue:(float)hue atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    const CGFloat PH  = 60.0f;
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(p, y, w, PH)];
    pill.backgroundColor = [self pillColor];
    pill.layer.cornerRadius = 10;
    pill.layer.borderWidth = 0.5;
    pill.layer.borderColor = [[self secondaryTextColor] colorWithAlphaComponent:0.15].CGColor;
    pill.clipsToBounds = YES;
    pill.tag = tag;
    [self.contentContainer addSubview:pill];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 140, 18)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    lbl.textColor = [self textColor];
    [pill addSubview:lbl];

    UILabel *colorName = [[UILabel alloc] initWithFrame:CGRectMake(w - 80, 8, 66, 18)];
    colorName.text = [NSString stringWithFormat:@"%d", (int)(hue * 360)];
    colorName.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    colorName.textAlignment = NSTextAlignmentRight;
    colorName.textColor = [self accentColor];
    colorName.tag = 8800;
    [pill addSubview:colorName];

    const CGFloat TRK_H = 8.0f;
    const CGFloat THR   = 26.0f;
    const CGFloat trkY  = 34.0f;
    const CGFloat trkX  = 14.0f;
    const CGFloat trkW  = w - trkX * 2;

    UIView *trackBg = [[UIView alloc] initWithFrame:CGRectMake(trkX, trkY + (THR - TRK_H)*0.5f, trkW, TRK_H)];
    trackBg.backgroundColor = [UIColor colorWithWhite:0.5 alpha:1];
    trackBg.layer.cornerRadius = TRK_H * 0.5f;
    [pill addSubview:trackBg];

    UIColor *hueColor = [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1.0];
    UIView *trackFill = [[UIView alloc] initWithFrame:CGRectMake(trkX, trkY + (THR - TRK_H)*0.5f, trkW * hue, TRK_H)];
    trackFill.backgroundColor = hueColor;
    trackFill.layer.cornerRadius = TRK_H * 0.5f;
    trackFill.tag = 8802;
    [pill addSubview:trackFill];

    float thumbX = trkX + trkW * hue - THR * 0.5f;
    UIView *thumb = [[UIView alloc] initWithFrame:CGRectMake(thumbX, trkY, THR, THR)];
    thumb.backgroundColor = [UIColor whiteColor];
    thumb.layer.cornerRadius = THR * 0.5f;
    thumb.layer.borderWidth = 2;
    thumb.layer.borderColor = [self accentColor].CGColor;
    thumb.tag = 8801;
    [pill addSubview:thumb];

    objc_setAssociatedObject(pill, "trkX",  @(trkX),  OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pill, "trkW",  @(trkW),  OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pill, "trkY",  @(trkY),  OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pill, "THR",   @(THR),   OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pill, "thumb", thumb,     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pill, "cname", colorName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pill, "fill",  trackFill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(hueSliderPanned:)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hueSliderTapped:)];
    [pill addGestureRecognizer:pan];
    [pill addGestureRecognizer:tap];

    return y + PH + 8.0f;
}

static float clamp01(float v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

- (void)applyHue:(float)hue tag:(int)tag thumb:(UIView *)thumb colorName:(UILabel *)colorName fill:(UIView *)fill trackW:(float)trkW trackX:(float)trkX {
    hue = clamp01(hue);
    UIColor *col = [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1.0];
    colorName.text = [NSString stringWithFormat:@"%d", (int)(hue * 360)];
    CGRect f = fill.frame;
    f.size.width = trkW * hue;
    fill.frame = f;
    fill.backgroundColor = col;

    CGFloat r,g,b,a; [col getRed:&r green:&g blue:&b alpha:&a];
    switch (tag) {
        case 8001: espLineHue=hue;     Vars.espLineColor[0]=r;    Vars.espLineColor[1]=g;    Vars.espLineColor[2]=b;    break;
        case 8002: espBoxHue=hue;      Vars.espBoxColor[0]=r;     Vars.espBoxColor[1]=g;     Vars.espBoxColor[2]=b;     break;
        case 8003: espSkeletonHue=hue; Vars.espSkeletonColor[0]=r;Vars.espSkeletonColor[1]=g;Vars.espSkeletonColor[2]=b;break;
        case 8004: espFovHue=hue;      Vars.fovLineColor[0]=r;    Vars.fovLineColor[1]=g;    Vars.fovLineColor[2]=b;    break;
    }
}

- (void)hueSliderPanned:(UIPanGestureRecognizer *)pan {
    UIView *pill = pan.view;
    float trkX = [objc_getAssociatedObject(pill, "trkX") floatValue];
    float trkW = [objc_getAssociatedObject(pill, "trkW") floatValue];
    float trkY = [objc_getAssociatedObject(pill, "trkY") floatValue];
    float THR = [objc_getAssociatedObject(pill, "THR") floatValue];
    UIView *thumb = objc_getAssociatedObject(pill, "thumb");
    UILabel *colorName = objc_getAssociatedObject(pill, "cname");
    UIView *fill = objc_getAssociatedObject(pill, "fill");

    CGPoint loc = [pan locationInView:pill];
    float hue = clamp01((loc.x - trkX) / trkW);
    float thumbX = trkX + trkW * hue - THR * 0.5f;
    thumb.frame = CGRectMake(thumbX, trkY, THR, THR);
    [self applyHue:hue tag:(int)pill.tag thumb:thumb colorName:colorName fill:fill trackW:trkW trackX:trkX];
}

- (void)hueSliderTapped:(UITapGestureRecognizer *)tap {
    UIView *pill = tap.view;
    float trkX = [objc_getAssociatedObject(pill, "trkX") floatValue];
    float trkW = [objc_getAssociatedObject(pill, "trkW") floatValue];
    float trkY = [objc_getAssociatedObject(pill, "trkY") floatValue];
    float THR = [objc_getAssociatedObject(pill, "THR") floatValue];
    UIView *thumb = objc_getAssociatedObject(pill, "thumb");
    UILabel *colorName = objc_getAssociatedObject(pill, "cname");
    UIView *fill = objc_getAssociatedObject(pill, "fill");

    CGPoint loc = [tap locationInView:pill];
    float hue = clamp01((loc.x - trkX) / trkW);
    float thumbX = trkX + trkW * hue - THR * 0.5f;
    thumb.frame = CGRectMake(thumbX, trkY, THR, THR);
    [self applyHue:hue tag:(int)pill.tag thumb:thumb colorName:colorName fill:fill trackW:trkW trackX:trkX];
}

- (CGFloat)addSliderPill:(NSString *)title value:(CGFloat)val min:(CGFloat)min max:(CGFloat)max selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(p, y, w, 62)];
    pill.backgroundColor = [self pillColor];
    pill.layer.cornerRadius = 10;
    pill.layer.borderWidth = 0.5;
    pill.layer.borderColor = [[self secondaryTextColor] colorWithAlphaComponent:0.15].CGColor;
    [self.contentContainer addSubview:pill];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, w - 80, 20)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    lbl.textColor = [self textColor];
    [pill addSubview:lbl];

    UILabel *valL = [[UILabel alloc] initWithFrame:CGRectMake(w - 70, 8, 56, 20)];
    valL.text = [NSString stringWithFormat:DSTR("%.0f"), val];
    valL.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    valL.textColor = [self accentColor];
    valL.textAlignment = NSTextAlignmentRight;
    [pill addSubview:valL];

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(14, 32, w - 28, 24)];
    sl.minimumValue = min;
    sl.maximumValue = max;
    sl.value = val;
    sl.minimumTrackTintColor = [self accentColor];
    sl.maximumTrackTintColor = [[self secondaryTextColor] colorWithAlphaComponent:0.3];

    objc_setAssociatedObject(sl, "valLabel", valL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sl addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    [pill addSubview:sl];

    return y + 68;
}

- (CGFloat)addButtonPill:(NSString *)title selector:(SEL)sel atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(p, y, w, 42)];
    btn.backgroundColor = [self pillColor];
    btn.layer.cornerRadius = 10;
    btn.layer.borderWidth = 0.5;
    btn.layer.borderColor = [[self accentColor] colorWithAlphaComponent:0.35].CGColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[self accentColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [self.contentContainer addSubview:btn];
    return y + 48;
}

#pragma mark - Actions

- (void)toggleVar:(UIButton *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    BOOL newState = ![self.checkboxStates[key] boolValue];
    self.checkboxStates[key] = @(newState);

    if ([key isEqualToString:@"Aimbot"]) Vars.Aimbot = newState;
    else if ([key isEqualToString:@"AimKillSend"]) Vars.AimKillSend = newState;
    else if ([key isEqualToString:@"SpinBotEnabled"]) Vars.SpinBotEnabled = newState;
    else if ([key isEqualToString:@"isAimFov"]) Vars.isAimFov = newState;
    else if ([key isEqualToString:@"VisibleCheck"]) Vars.VisibleCheck = newState;
    else if ([key isEqualToString:@"IgnoreKnocked"]) Vars.IgnoreKnocked = newState;
    else if ([key isEqualToString:@"Enable"]) Vars.Enable = newState;
    else if ([key isEqualToString:@"lines"]) Vars.lines = newState;
    else if ([key isEqualToString:@"Box"]) Vars.Box = newState;
    else if ([key isEqualToString:@"Name"]) Vars.Name = newState;
    else if ([key isEqualToString:@"Health"]) Vars.Health = newState;
    else if ([key isEqualToString:@"skeleton"]) Vars.skeleton = newState;
    else if ([key isEqualToString:@"Distance"]) Vars.Distance = newState;
    else if ([key isEqualToString:@"circlepos"]) Vars.circlepos = newState;
    else if ([key isEqualToString:@"enemycount"]) Vars.enemycount = newState;
    else if ([key isEqualToString:@"CamXa"]) Vars.camxa = newState;
    else if ([key isEqualToString:@"ShowAutoFireButton"]) {
        g_showAutoFireButton = newState;
        if (newState) [self autoFireModeUI];
        else {
            if (self.autoFireButtonView) {
                [self.autoFireButtonView removeFromSuperview];
                self.autoFireButtonView = nil;
            }
        }
    }
    else if ([key isEqualToString:@"ShowUnderButton"]) {
        g_showUnderButton = newState;
        if (newState) [self underModeUI];
        else {
            if (self.underButtonView) {
                [self.underButtonView removeFromSuperview];
                self.underButtonView = nil;
            }
        }
    }
    else if ([key isEqualToString:@"Underground"]) {
        Vars.Underground = newState;
    }
    else if ([key isEqualToString:@"vohandan"]) Vars.vohandan = newState;
    else if ([key isEqualToString:@"noreload"]) Vars.noreload = newState;
    else if ([key isEqualToString:@"AIRPlayer"]) Vars.AIRPlayer = newState;
    else if ([key isEqualToString:@"telekill"]) Vars.telekill = newState;
    else if ([key isEqualToString:@"fastfire"]) Vars.fastfire = newState;
    else if ([key isEqualToString:@"Nangdich"]) Vars.Nangdich = newState;
    else if ([key isEqualToString:@"SilentAim"]) Vars.SilentAim = newState;
    else if ([key isEqualToString:@"doublegun"]) doublegun = newState;
    else if ([key isEqualToString:@"resetguest"]) resetguest = newState;
    // ✅ Đã xoá: fmedkit, highfps120 handlers
    else if ([key isEqualToString:@"SettingsDarkMode"]) { isDarkMode = newState; [self forceUpdateColors]; [self loadTabContent:self.currentTab]; return; }
    else if ([key isEqualToString:@"StreamProof"]) { isStreamProof = newState; [self handleStreamProof:newState]; [self loadTabContent:self.currentTab]; return; }

    else if ([key isEqualToString:@"SpeedX50"]) { SpeedX50Enabled = newState; ApplySpeedX50(newState); }

    else if ([key isEqualToString:@"NoRecoil"]) { NoRecoilEnabled = newState; [self toggleNoRecoil:newState]; }
    else if ([key isEqualToString:@"AimRandom"]) Vars.AimRandomEnable = newState;

    NSSet *keysWithSlider = [NSSet setWithArray:@[ @"CamXa", @"lines", @"Box", @"skeleton", @"SpinBotEnabled", @"enemycount", @"AimRandom" ]];
    if ([keysWithSlider containsObject:key]) {
        [self loadTabContent:self.currentTab];
    } else {
        UIButton *cb = self.allCheckboxes[key];
        if (cb) {
            UIView *thumb = [cb viewWithTag:777];
            [UIView animateWithDuration:0.2 animations:^{
                cb.backgroundColor = newState ? [self accentColor] : [self checkboxOffColor];
                if (thumb) {
                    thumb.frame = CGRectMake(newState ? (44.0f - 18.0f - 3.0f) : 3.0f, 3.0f, 18.0f, 18.0f);
                    thumb.backgroundColor = newState ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
                }
            }];
        }
    }
}

- (CGFloat)addComboRow:(NSString *)title options:(NSArray *)options optionNames:(const char **)names selectedIdx:(int)sel tag:(NSInteger)tag atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(p + 4, y + 4, w, 18)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    lbl.textColor = [self secondaryTextColor];
    [self.contentContainer addSubview:lbl];
    y += 26;

    CGFloat btnH = 40.0;
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(p, y, w, btnH)];
    pill.backgroundColor = [self pillColor];
    pill.layer.cornerRadius = 10;
    pill.layer.borderWidth = 0.5;
    pill.layer.borderColor = [[self secondaryTextColor] colorWithAlphaComponent:0.15].CGColor;
    pill.clipsToBounds = YES;
    [self.contentContainer addSubview:pill];

    NSInteger count = options.count;
    CGFloat btnW = w / count;
    for (NSInteger i = 0; i < count; i++) {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(btnW * i, 0, btnW, btnH)];
        btn.tag = tag * 100 + i;

        if (i == sel) {
            UIView *bg = [[UIView alloc] initWithFrame:CGRectMake(4, 4, btnW - 8, btnH - 8)];
            bg.backgroundColor = [self accentColor];
            bg.layer.cornerRadius = 8;
            [btn addSubview:bg];
        }

        UILabel *optLbl = [[UILabel alloc] initWithFrame:btn.bounds];
        optLbl.text = names ? [NSString stringWithUTF8String:names[i]] : [NSString stringWithFormat:DSTR("%ld"), (long)i];
        optLbl.textAlignment = NSTextAlignmentCenter;
        optLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
        optLbl.textColor = (i == sel) ? [UIColor whiteColor] : [self textColor];
        [btn addSubview:optLbl];

        [btn addTarget:self action:@selector(comboOptionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [pill addSubview:btn];
    }

    return y + btnH + 10;
}

- (void)comboOptionTapped:(UIButton *)sender {
    NSInteger tag = sender.tag;
    NSInteger groupTag = tag / 100;
    NSInteger idx = tag % 100;

    if (groupTag == 3001) Vars.AimWhen = (int)idx;
    else if (groupTag == 3002) Vars.AimHitbox = (int)idx;
    else if (groupTag == 3003) Vars.AimMode = (int)idx;
    else if (groupTag == 3004) {
        NSString *code = (idx == 0) ? @"vi" : @"en";
        [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"vntool_esp_lang"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        extern int g_espLang;
        g_espLang = (idx == 0) ? 1 : 0;
    }
    else if (groupTag == 3005) Vars.AimRandomMode = (int)idx;

    [self loadTabContent:self.currentTab];
}

- (void)sliderESPDistanceChanged:(UISlider *)s { Vars.espDrawDistance = s.value; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); if (vl) vl.text = [NSString stringWithFormat:DSTR("%.0fm"), s.value]; }
- (void)sliderSpinBotSpeedChanged:(UISlider *)s { Vars.SpinBotSpeed = s.value; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); vl.text = [NSString stringWithFormat:DSTR("%.0f"), s.value]; }
- (void)sliderSpeedChanged:(UISlider *)s { Vars.AimSpeed = s.value; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); vl.text = [NSString stringWithFormat:DSTR("%.0f"), s.value]; }
- (void)sliderFovChanged:(UISlider *)s { Vars.AimFov = s.value; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); vl.text = [NSString stringWithFormat:DSTR("%.0f"), s.value]; }
- (void)sliderCamXaChanged:(UISlider *)s { Vars.CamXaValue = s.value; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); vl.text = [NSString stringWithFormat:DSTR("%.0f"), s.value]; }
- (void)sliderAutoFireDelayChanged:(UISlider *)s { Vars.AutoFireDelay = s.value / 1000.f; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); vl.text = [NSString stringWithFormat:DSTR("%.0fms"), s.value]; }
- (void)sliderDelayChanged:(UISlider *)s { fixLoginTimeout = s.value; UILabel *vl = objc_getAssociatedObject(s, "valLabel"); vl.text = [NSString stringWithFormat:DSTR("%.0f"), s.value]; }

- (void)fixLoginTapped {
    self.floatingPanel.hidden = YES;
    MenDeal = false;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(fixLoginTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.floatingPanel.hidden = NO;
        MenDeal = true;
    });
}

- (void)changeCornerStyle:(UIButton *)sender {
    menuCornerStyle = (int)(sender.tag - 60000);
    [self applyCornerStyle];
    [self loadTabContent:self.currentTab];
}

- (void)applyCornerStyle {
    CGFloat radius = (menuCornerStyle == 0) ? 16.0f : 6.0f;

    self.floatingPanel.layer.mask = nil;
    self.floatingPanel.layer.cornerRadius = 0;
    self.sidebarBg.layer.mask = nil;
    self.sidebarBg.layer.cornerRadius = 0;

    if (radius <= 0) {
        self.floatingPanel.clipsToBounds = YES;
        self.sidebarBg.clipsToBounds = NO;
        return;
    }

    CGRect pb = self.floatingPanel.bounds;
    UIBezierPath *panelPath = [UIBezierPath bezierPathWithRoundedRect:pb
                                                   byRoundingCorners:UIRectCornerAllCorners
                                                         cornerRadii:CGSizeMake(radius, radius)];
    CAShapeLayer *panelMask = [CAShapeLayer layer];
    panelMask.path = panelPath.CGPath;
    panelMask.frame = pb;
    self.floatingPanel.layer.mask = panelMask;
    self.floatingPanel.clipsToBounds = YES;

    CGRect sb = self.sidebarBg.bounds;
    UIBezierPath *sidebarPath = [UIBezierPath bezierPathWithRoundedRect:sb
                                                     byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerBottomLeft)
                                                           cornerRadii:CGSizeMake(radius, radius)];
    CAShapeLayer *sidebarMask = [CAShapeLayer layer];
    sidebarMask.path = sidebarPath.CGPath;
    sidebarMask.frame = sb;
    self.sidebarBg.layer.mask = sidebarMask;
    self.sidebarBg.clipsToBounds = NO;
}

- (void)feedbackTelegramTapped {
    NSURL *url = [NSURL URLWithString:@"https://t.me/vntool"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)logoutTapped {
    NSLog(@"[VNTool] Logout tapped");
}

- (void)sliderAlphaChanged:(UISlider *)s {
    menuAlpha = s.value / 100.0f;
    self.floatingPanel.alpha = menuAlpha;
    UILabel *vl = objc_getAssociatedObject(s, "valLabel");
    vl.text = [NSString stringWithFormat:DSTR("%.0f%%"), s.value];
}

- (void)sliderScaleChanged:(UISlider *)s {
    menuScale = s.value;
    self.floatingPanel.transform = CGAffineTransformMakeScale(menuScale, menuScale);
    UILabel *vl = objc_getAssociatedObject(s, "valLabel");
    vl.text = [NSString stringWithFormat:DSTR("%.1fx"), s.value];
}

- (void)toggleStreamProof:(UIButton *)sender { isStreamProof = !isStreamProof; [self handleStreamProof:isStreamProof]; }

- (void)settingsToggleTheme:(UIButton *)sender {
    isDarkMode = !isDarkMode;
    [self.themeToggle setImage:[UIImage systemImageNamed:isDarkMode ? @"moon.fill" : @"sun.max.fill"] forState:UIControlStateNormal];
    [self loadTabContent:self.currentTab];
    [self forceUpdateColors];
}

- (void)resetSettingsTapped {
    menuAlpha = 1.0f;
    menuScale = 1.0f;
    MenuColorTheme = 1;
    menuCornerStyle = 0;
    isDarkMode = NO;

    self.floatingPanel.alpha = menuAlpha;
    self.floatingPanel.transform = CGAffineTransformIdentity;
    [self applyCornerStyle];
    [self loadTabContent:self.currentTab];
    [self forceUpdateColors];
}

- (void)changeMenuTheme:(UIButton *)sender {
    MenuColorTheme = (int)(sender.tag - 50000);
    [self loadTabContent:self.currentTab];
    [self forceUpdateColors];
}

- (void)toggleTheme {
    isDarkMode = !isDarkMode;
    [self.themeToggle setImage:[UIImage systemImageNamed:isDarkMode ? @"moon.fill" : @"sun.max.fill"] forState:UIControlStateNormal];
    [self loadTabContent:self.currentTab];
    [self forceUpdateColors];
}

- (void)forceUpdateColors {
    self.floatingPanel.backgroundColor = [self backgroundColor];
    self.floatingPanel.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:0.35].CGColor;
    self.sidebarBg.backgroundColor = [self sidebarBackgroundColor];
    if (self.closeButton) {
        self.closeButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.4];
    }
    [self updateSidebarForTab:self.currentTab];
}

- (void)handleStreamProof:(BOOL)enabled {
    static UIView *secureContainer = nil;
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;

    if (enabled) {
        if (!secureContainer) {
            UITextField *tf = [[UITextField alloc] init];
            [tf setSecureTextEntry:YES];
            secureContainer = [tf.subviews firstObject];
            [secureContainer setUserInteractionEnabled:YES];
            secureContainer.frame = [UIScreen mainScreen].bounds;
        }
        if (self.view.superview != secureContainer) {
            [self.view removeFromSuperview];
            [secureContainer addSubview:self.view];
            [keyWindow addSubview:secureContainer];
        }
        if (self.floatingPanel.superview != secureContainer) {
            [self.floatingPanel removeFromSuperview];
            [secureContainer addSubview:self.floatingPanel];
        }
    } else {
        if (self.floatingPanel.superview && self.floatingPanel.superview != keyWindow) {
            [self.floatingPanel removeFromSuperview];
            [keyWindow addSubview:self.floatingPanel];
        }
        if (self.view.superview && self.view.superview != keyWindow) {
            [self.view removeFromSuperview];
            [keyWindow addSubview:self.view];
        }
        if (secureContainer) {
            [secureContainer removeFromSuperview];
            secureContainer = nil;
        }
    }
}

- (void)animateClose { MenDeal = false; }

#pragma mark - VÒNG LẶP RENDER CHÍNH

- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;
    CGFloat fbScale = view.window.screen.nativeScale ?: UIScreen.mainScreen.nativeScale;
    io.DisplayFramebufferScale = ImVec2(fbScale, fbScale);
    io.DeltaTime = 1.0f / float(view.preferredFramesPerSecond ?: 60);

    static BOOL lastMenDeal = YES;
    if ((BOOL)MenDeal != lastMenDeal) {
        lastMenDeal = (BOOL)MenDeal;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.floatingPanel.hidden = !MenDeal;
            self.view.userInteractionEnabled = MenDeal;
        });
    }

    id<MTLCommandBuffer> cmdBuf = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;

    if (rpd != nil) {
        id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
        [enc pushDebugGroup:@"ImGui_ESP"];

        ImGui_ImplMetal_NewFrame(rpd);
        ImGui::NewFrame();

        ImGui::GetBackgroundDrawList();
        get_players();
        draw_watermark();
        aimbot();
        RunAIRPlayer();

        Vars.isAimFov = (Vars.AimFov > 0);

        ImGui::Render();
        ImDrawData* dd = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(dd, cmdBuf, enc);

        [enc popDebugGroup];
        [enc endEncoding];
       [cmdBuf presentDrawable:view.currentDrawable];
    }
    [cmdBuf commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}

@end