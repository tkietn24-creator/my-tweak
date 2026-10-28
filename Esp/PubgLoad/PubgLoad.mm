#import "PubgLoad.h"
#import <UIKit/UIKit.h>
#import "JHPP.h"
#import "ImGuiLoad.h"
#import "ImGuiDrawView.h"
#import "oxorany/oxorany.h"

#import <sys/syscall.h>
#import <unistd.h>
#import <sys/stat.h>
#import <sys/utsname.h>

#define OBF(x) [NSString stringWithUTF8String:oxorany(x)]

#define FIREBASE_PROJECT_ID OBF("vntool-license")
#define LICENSE_COLLECTION  OBF("licenses")
#define UD_KEY_SAVED        OBF("VNTOOL_LICENSE_KEY")

bool MenDeal = false;
static PubgLoad *extraInfo;
UIWindow *mainWindow;

@interface PubgLoad()
@property (nonatomic, strong) ImGuiDrawView *vna;
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, assign) BOOL isMenuShown;
@end

@implementation PubgLoad

#pragma mark - Device ID
+ (NSString *)deviceID {
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return udid ?: OBF("unknown-device");
}

#pragma mark - HTTP helper
+ (NSDictionary *)httpGetJSON:(NSString *)urlStr status:(NSInteger *)outCode {
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 15;

    __block NSData *respData = nil;
    __block NSInteger code = 0;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e){
            respData = d;
            if ([r isKindOfClass:[NSHTTPURLResponse class]])
                code = [(NSHTTPURLResponse *)r statusCode];
            dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 20*NSEC_PER_SEC));
    if (outCode) *outCode = code;
    if (!respData) return nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
    return [json isKindOfClass:[NSDictionary class]] ? json : nil;
}

#pragma mark - Maintenance
+ (NSInteger)maintenanceStateMessage:(NSString **)outMsg {
    NSString *urlStr = [NSString stringWithFormat:
        OBF("https://firestore.googleapis.com/v1/projects/%@/databases/(default)/documents/system/maintenance"),
        FIREBASE_PROJECT_ID];
    NSInteger code = 0;
    NSDictionary *json = [self httpGetJSON:urlStr status:&code];
    if (!json || code != 200) {
        return -1;
    }
    NSDictionary *fields = json[OBF("fields")];
    BOOL enabled = [fields[OBF("enabled")][OBF("booleanValue")] boolValue];
    NSString *msg = fields[OBF("message")][OBF("stringValue")] ?: OBF("");
    if (outMsg) *outMsg = msg;
    return enabled ? 1 : 0;
}

#pragma mark - Firestore REST
+ (NSDictionary *)firestoreGetLicense:(NSString *)key {
    NSString *urlStr = [NSString stringWithFormat:
        OBF("https://firestore.googleapis.com/v1/projects/%@/databases/(default)/documents/%@/%@"),
        FIREBASE_PROJECT_ID, LICENSE_COLLECTION, [key uppercaseString]];
    NSInteger code = 0;
    NSDictionary *json = [self httpGetJSON:urlStr status:&code];
    if (!json) { return nil; }
    if (json[OBF("error")]) {
        return nil;
    }
    return json[OBF("fields")];
}

+ (BOOL)firestorePatchLicense:(NSString *)key
                    deviceIDs:(NSArray<NSString *> *)deviceIDs
                  activations:(NSInteger)activations {
    NSString *urlStr = [NSString stringWithFormat:
        OBF("https://firestore.googleapis.com/v1/projects/%@/databases/(default)/documents/%@/%@?updateMask.fieldPaths=device_ids&updateMask.fieldPaths=activations"),
        FIREBASE_PROJECT_ID, LICENSE_COLLECTION, [key uppercaseString]];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = OBF("PATCH");
    [req setValue:OBF("application/json") forHTTPHeaderField:OBF("Content-Type")];
    req.timeoutInterval = 15;

    NSMutableArray *arrVals = [NSMutableArray array];
    for (NSString *d in deviceIDs) {
        [arrVals addObject:@{OBF("stringValue"): d}];
    }
    NSDictionary *body = @{
        OBF("fields"): @{
            OBF("device_ids"):  @{OBF("arrayValue"): @{OBF("values"): arrVals}},
            OBF("activations"): @{OBF("integerValue"): [@(activations) stringValue]}
        }
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    __block NSInteger code = 0;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e){
            if ([r isKindOfClass:[NSHTTPURLResponse class]])
                code = [(NSHTTPURLResponse *)r statusCode];
            dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 20*NSEC_PER_SEC));
    return code == 200;
}

#pragma mark - Date parse
+ (NSDate *)parseIsoDate:(NSString *)s {
    if (!s.length) return nil;
    NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *d = [iso dateFromString:s];
    if (d) return d;
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    return [iso dateFromString:s];
}

#pragma mark - Verify logic
+ (NSInteger)verifyKeyDetailed:(NSString *)key {
    NSDictionary *fields = [self firestoreGetLicense:key];
    if (!fields) return 1;

    NSString *status = fields[OBF("status")][OBF("stringValue")];
    if (![status isEqualToString:OBF("active")]) {
        return 2;
    }

    NSString *expiresStr = fields[OBF("expires_at")][OBF("timestampValue")]
                         ?: fields[OBF("expires_at")][OBF("stringValue")];
    if (expiresStr) {
        NSDate *exp = [self parseIsoDate:expiresStr];
        if (exp && [exp timeIntervalSinceNow] < 0) {
            return 2;
        }
    }

    NSInteger maxAct = [fields[OBF("max_activations")][OBF("integerValue")] integerValue];
    NSInteger curAct = [fields[OBF("activations")][OBF("integerValue")] integerValue];
    NSArray *devVals = fields[OBF("device_ids")][OBF("arrayValue")][OBF("values")];
    NSMutableArray<NSString *> *devIDs = [NSMutableArray array];
    for (NSDictionary *v in devVals) {
        NSString *s = v[OBF("stringValue")];
        if (s) [devIDs addObject:s];
    }

    NSString *thisDev = [self deviceID];
    if ([devIDs containsObject:thisDev]) return 0;

    if (maxAct > 0 && curAct >= maxAct) {
        return 3;
    }
    [devIDs addObject:thisDev];
    BOOL ok = [self firestorePatchLicense:key deviceIDs:devIDs activations:curAct + 1];
    return ok ? 0 : 4;
}

+ (BOOL)verifyKey:(NSString *)key {
    return [self verifyKeyDetailed:key] == 0;
}

#pragma mark - UI prompt
+ (void)promptKeyOnRoot:(UIViewController *)root completion:(void(^)(BOOL ok, NSInteger reason))cb {
    NSString *lang = [[NSUserDefaults standardUserDefaults] stringForKey:OBF("vntool_lang")] ?: OBF("vi");
    BOOL isVi = [lang isEqualToString:OBF("vi")];

    NSString *title       = OBF("Việt Nam Tool");
    NSString *message     = isVi ? OBF("Nhập license key để kích hoạt") : OBF("Enter license key to activate");
    NSString *placeholder = OBF("KEY_CODE");
    NSString *activateBtn = isVi ? OBF("Kích hoạt") : OBF("Activate");
    NSString *cancelBtn   = isVi ? OBF("Thoát")     : OBF("Exit");

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = placeholder;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:activateBtn style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * _Nonnull action) {
            NSString *key = [ac.textFields.firstObject.text
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (key.length == 0) { cb(NO, 1); return; }
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                NSInteger r = [self verifyKeyDetailed:key];
                if (r == 0) [[NSUserDefaults standardUserDefaults] setObject:key forKey:UD_KEY_SAVED];
                dispatch_async(dispatch_get_main_queue(), ^{ cb(r==0, r); });
            });
        }]];
    [ac addAction:[UIAlertAction actionWithTitle:cancelBtn style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * _Nonnull action) { cb(NO, 1); }]];
    [root presentViewController:ac animated:YES completion:nil];
}

+ (NSString *)reasonText:(NSInteger)r {
    NSString *lang = [[NSUserDefaults standardUserDefaults] stringForKey:OBF("vntool_lang")] ?: OBF("vi");
    BOOL isVi = [lang isEqualToString:OBF("vi")];

    switch (r) {
        case 1: return isVi ? OBF("Key không tồn tại.") : OBF("Key does not exist.");
        case 2: return isVi ? OBF("Key đã bị thu hồi hoặc hết hạn.") : OBF("Key has been revoked or expired.");
        case 3: return isVi ? OBF("Key đã vượt số máy cho phép.") : OBF("Key has exceeded the allowed device limit.");
        case 4: return isVi ? OBF("Không kết nối được server (kiểm tra mạng hoặc Firestore Rules).")
                             : OBF("Could not connect to server (check network or Firestore Rules).");
        default: return isVi ? OBF("Key không hợp lệ.") : OBF("Invalid key.");
    }
}

+ (void)showMaintenance:(NSString *)msg on:(UIViewController *)root {
    NSString *lang = [[NSUserDefaults standardUserDefaults] stringForKey:OBF("vntool_lang")] ?: OBF("vi");
    BOOL isVi = [lang isEqualToString:OBF("vi")];

    NSString *title = isVi ? OBF("🛠 Bảo trì") : OBF("🛠 Maintenance");
    NSString *m = msg.length ? msg
        : (isVi ? OBF("Server đang bảo trì, vui lòng quay lại sau.")
                : OBF("Server is under maintenance, please come back later."));
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:title
        message:m
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:OBF("OK") style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a){ exit(0); }]];
    [root presentViewController:ac animated:YES completion:nil];
}

+ (void)afterMaintenanceCheck:(void(^)(void))next {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *msg = nil;
        NSInteger st = [self maintenanceStateMessage:&msg];
        if (st == 1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *root = [JHPP currentViewController];
                if (root) [self showMaintenance:msg on:root];
                else dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2*NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{ [self afterMaintenanceCheck:next]; });
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), next);
    });
}

+ (void)showLanguageSelection:(void(^)(void))next {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud stringForKey:OBF("vntool_lang")]) { next(); return; }

    UIViewController *root = [JHPP currentViewController];
    if (!root) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ [self showLanguageSelection:next]; });
        return;
    }

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:OBF("🌐 Ngôn ngữ / Language")
        message:OBF("Chọn ngôn ngữ giao diện\nChoose interface language")
        preferredStyle:UIAlertControllerStyleAlert];

    [ac addAction:[UIAlertAction actionWithTitle:OBF("🇻🇳 Tiếng Việt")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            [ud setObject:OBF("vi") forKey:OBF("vntool_lang")];
            [ud synchronize];
            next();
        }]];
    [ac addAction:[UIAlertAction actionWithTitle:OBF("🇺🇸 English")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            [ud setObject:OBF("en") forKey:OBF("vntool_lang")];
            [ud synchronize];
            next();
        }]];

    [root presentViewController:ac animated:YES completion:nil];
}

+ (void)showKeyExpiryNotice:(NSString *)isoExpires on:(UIViewController *)root {
    if (!isoExpires.length) return;
    NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
    fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *exp = [fmt dateFromString:isoExpires];
    if (!exp) {
        fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        exp = [fmt dateFromString:isoExpires];
    }
    if (!exp) return;

    NSTimeInterval sec = [exp timeIntervalSinceNow];
    if (sec <= 0) return;  

    long days  = (long)(sec / 86400);
    long hours = (long)((sec - days*86400) / 3600);
    long mins  = (long)((sec - days*86400 - hours*3600) / 60);

    NSString *timeStr;
    NSString *lang = [[NSUserDefaults standardUserDefaults] stringForKey:OBF("vntool_lang")] ?: OBF("vi");
    BOOL isVi = [lang isEqualToString:OBF("vi")];

    if (days > 0)
        timeStr = isVi
            ? [NSString stringWithFormat:OBF("%ld ngày %02ld giờ %02ld phút"), days, hours, mins]
            : [NSString stringWithFormat:OBF("%ld days %02ldh %02ldm"), days, hours, mins];
    else
        timeStr = isVi
            ? [NSString stringWithFormat:OBF("%02ld giờ %02ld phút"), hours, mins]
            : [NSString stringWithFormat:OBF("%02ldh %02ldm remaining"), hours, mins];

    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = OBF("dd/MM/yyyy HH:mm");
    NSString *expStr = [df stringFromDate:exp];

    NSString *title = isVi ? OBF("🔑 Key của bạn") : OBF("🔑 Your License");
    NSString *msg   = isVi
        ? [NSString stringWithFormat:OBF("Còn lại: %@\nHết hạn: %@"), timeStr, expStr]
        : [NSString stringWithFormat:OBF("Remaining: %@\nExpires: %@"), timeStr, expStr];
    NSString *ok    = isVi ? OBF("OK") : OBF("OK");

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:title message:msg
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:ok style:UIAlertActionStyleDefault handler:nil]];

    dispatch_async(dispatch_get_main_queue(), ^{
        [root presentViewController:ac animated:YES completion:nil];
    });
}

+ (void)runLicenseGate {
    [self afterMaintenanceCheck:^{
        [self showLanguageSelection:^{
            NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:UD_KEY_SAVED];
            if (saved.length > 0) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    NSInteger r = [self verifyKeyDetailed:saved];
                    if (r == 0) {
                        NSDictionary *fields = [self firestoreGetLicense:saved];
                        NSString *expiresStr = fields[OBF("expires_at")][OBF("timestampValue")]
                                           ?: fields[OBF("expires_at")][OBF("stringValue")];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self bootTweak];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),
                                dispatch_get_main_queue(), ^{
                                UIViewController *root = [JHPP currentViewController];
                                if (root && expiresStr.length)
                                    [self showKeyExpiryNotice:expiresStr on:root];
                            });
                        });
                    } else {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:UD_KEY_SAVED];
                        dispatch_async(dispatch_get_main_queue(), ^{ [self askKey]; });
                    }
                });
            } else {
                [self askKey];
            }
        }];
    }];
}

+ (void)askKey {
    UIViewController *root = [JHPP currentViewController];
    if (!root) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ [self askKey]; });
        return;
    }
    [self promptKeyOnRoot:root completion:^(BOOL ok, NSInteger reason){
        if (ok) {
            NSString *key2 = [[NSUserDefaults standardUserDefaults] stringForKey:UD_KEY_SAVED];
            [self bootTweak];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                UIViewController *root2 = [JHPP currentViewController];
                if (root2 && key2.length) {
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                        NSDictionary *fields = [self firestoreGetLicense:key2];
                        NSString *expiresStr = fields[OBF("expires_at")][OBF("timestampValue")]
                                           ?: fields[OBF("expires_at")][OBF("stringValue")];
                        if (expiresStr.length)
                            [self showKeyExpiryNotice:expiresStr on:root2];
                    });
                }
            });
        } else {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:OBF("Sai key")
                message:[self reasonText:reason]
                preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:OBF("Thử lại") style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a){ [self askKey]; }]];
            [ac addAction:[UIAlertAction actionWithTitle:OBF("Thoát") style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *a){ exit(0); }]];
            [root presentViewController:ac animated:YES completion:nil];
        }
    }];
}

#pragma mark - Boot tweak
+ (void)bootTweak {
    syscall(26, 31, 0, 0, 0);
    mainWindow = [UIApplication sharedApplication].keyWindow;
    if (!extraInfo) extraInfo = [PubgLoad new];
    
    // Tạo Button VN
    [extraInfo initFloatingButton];
    
    MenDeal = true;
    kick_hacker_delayed();
    [self startMaintenancePolling];
}

#pragma mark - Maintenance polling
+ (void)startMaintenancePolling {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(60*NSEC_PER_SEC)),
        dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        NSString *msg = nil;
        NSInteger st = [self maintenanceStateMessage:&msg];
        if (st == 1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *root = [JHPP currentViewController];
                if (root) [self showMaintenance:msg on:root];
                else exit(0);
            });
            return;
        }
        [self startMaintenancePolling];
    });
}

void kick_hacker_delayed() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(120*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        struct stat st;
        const char* path = oxorany("/Library/MobileSubstrate/DynamicLibraries/VNTOOL.dylib");
        if (stat(path, &st) == 0) {
            if (st.st_size != 43342832) { exit(0); }
        }
        if (!MenDeal) exit(0);
    });
}

+ (void)load {
    [super load];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5*NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        [self runLicenseGate];
    });
}

#pragma mark - Floating VN Button
- (void)initFloatingButton {
    if (self.floatingButton) return;
    
    // Kích thước nút 45x45
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(100, 100, 45, 45);
    self.floatingButton.layer.cornerRadius = 22.5;
    self.floatingButton.layer.masksToBounds = YES;
    
    // Màu nền đen mờ + viền đỏ
    self.floatingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.floatingButton.layer.borderWidth = 1.5;
    self.floatingButton.layer.borderColor = [UIColor redColor].CGColor;
    
    // Đặt chữ "VN"
    [self.floatingButton setTitle:OBF("VN") forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    
    // Sự kiện bấm nút
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    // Thêm PanGesture để kéo di chuyển nút linh hoạt trên màn hình
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:pan];
    
    // Add vào window
    UIWindow *targetWindow = [UIApplication sharedApplication].keyWindow;
    if (!targetWindow && [UIApplication sharedApplication].windows.count > 0) {
        targetWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    [targetWindow addSubview:self.floatingButton];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.floatingButton.superview];
    CGPoint newCenter = CGPointMake(self.floatingButton.center.x + translation.x,
                                    self.floatingButton.center.y + translation.y);
    
    // Giới hạn nút không bị kéo văng ra ngoài màn hình
    CGRect bounds = self.floatingButton.superview.bounds;
    newCenter.x = MIN(MAX(newCenter.x, self.floatingButton.frame.size.width / 2), bounds.size.width - self.floatingButton.frame.size.width / 2);
    newCenter.y = MIN(MAX(newCenter.y, self.floatingButton.frame.size.height / 2), bounds.size.height - self.floatingButton.frame.size.height / 2);
    
    self.floatingButton.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.floatingButton.superview];
}

- (void)toggleMenu {
    if (!self.vna) {
        self.vna = [[ImGuiDrawView alloc] init];
        UIWindow *targetWindow = [UIApplication sharedApplication].keyWindow;
        if (!targetWindow && [UIApplication sharedApplication].windows.count > 0) {
            targetWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        [targetWindow.rootViewController.view addSubview:self.vna.view];
    }
    
    self.isMenuShown = !self.isMenuShown;
    [ImGuiDrawView showChange:self.isMenuShown];
}

@end