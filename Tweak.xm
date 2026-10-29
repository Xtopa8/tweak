// =============================================================
//  MeituanRiderTweak.xm   v3.0
//  目标：美团众包 iOS (banma_iOS_crowdsource) 13.7.9
//  平台：iOS 16.3 arm64 / TrollStore + TrollFools
//
//  所有类名/方法名/参数类型均由砸壳二进制实测解析：
//    __objc_classlist 12808 类 / __objc_catlist 1102 分类
//
//  越狱检测中的 8 个方法挂在未知系统类的 category 上，
//  改用运行时全类扫描 swizzle，不猜测宿主类。
//
//  【不修改定位数据】导航不受影响
// =============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

// =============================================================
//  运行时工具：在全部已加载类中扫描指定 selector 并替换实现
// =============================================================

static void swizzleSelectorEverywhere(SEL sel, BOOL returnBool, long long intValue, BOOL returnNil) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    if (!classes) return;
    count = objc_getClassList(classes, count);

    id (^nilBlock)(id) = ^id(id _s) { return nil; };
    BOOL (^boolBlock)(id) = ^BOOL(id _s) { return returnBool ? NO : NO; };
    long long (^intBlock)(id) = ^long long(id _s) { return intValue; };

    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!cls) continue;
        // 实例方法
        Class targets[2] = { cls, object_getClass(cls) };
        for (int t = 0; t < 2; t++) {
            Class tgt = targets[t];
            if (!tgt) continue;
            unsigned int mcount = 0;
            Method *methods = class_copyMethodList(tgt, &mcount);
            if (!methods) continue;
            for (unsigned int j = 0; j < mcount; j++) {
                if (method_getName(methods[j]) == sel) {
                    IMP imp;
                    if (returnNil)      imp = imp_implementationWithBlock(nilBlock);
                    else if (returnBool) imp = imp_implementationWithBlock(boolBlock);
                    else                 imp = imp_implementationWithBlock(intBlock);
                    method_setImplementation(methods[j], imp);
                }
            }
            free(methods);
        }
    }
    free(classes);
}

// =============================================================
//  一、越狱检测绕过
// =============================================================

// 1.1 分类方法（宿主类未知，运行时全量扫描）
static void patchJailbreakCategories(void) {
    // 返回 BOOL 的
    swizzleSelectorEverywhere(@selector(bmp_isJailbreak),      YES, 0, NO);
    swizzleSelectorEverywhere(@selector(bmcs_isJailbreak),     YES, 0, NO);
    swizzleSelectorEverywhere(@selector(cipf_isJailBreak),     YES, 0, NO);
    swizzleSelectorEverywhere(@selector(cipf_isAppJailBreak),  YES, 0, NO);
    swizzleSelectorEverywhere(@selector(dp_appIsJailbroken),   YES, 0, NO);
    swizzleSelectorEverywhere(@selector(sakf_isJailBreak),     YES, 0, NO);
    swizzleSelectorEverywhere(@selector(mpc_isJailBreak),      YES, 0, NO);
    // 返回 long long 的
    swizzleSelectorEverywhere(@selector(fake_isJailbreak),     NO,  0, NO);
    // 返回 id 的
    swizzleSelectorEverywhere(@selector(readJailBreakFile),    NO,  0, YES);
}

// 1.2 具体类的检测点（已实测确认）
%hook NVJailbrokenChecker
+ (BOOL)appIsJailbroken { return NO; }
+ (BOOL)deviceIsJailbroken { return NO; }
%end

%hook SAKGuardCommon
+ (BOOL)checkJailBreak { return NO; }
%end

%hook BMPClientConfigManager
+ (id)reportJailbrokenAsynDegrade { return nil; }
+ (id)voiceOverspeedThreshold { return @(9999); }
%end

%hook BMCSJailbreakManager
- (NSArray *)jailbreakDylibs { return @[]; }
- (NSArray *)localForbiddenDylibs { return @[]; }
- (void)reportStaticsIfNeeded { }
- (void)reportRepeatPackageInfoIfNeeded { }
%end

%hook BMPWaybillGrabModel
- (BOOL)checkJailBreakLimitGrab:(id)x { return YES; }
%end

// =============================================================
//  二、★ 关闭 IoT 摄像头检测系统
// =============================================================

%hook BMPIoTTrafficLightConfig

- (long long)MATRIX_DETECT_SWITCH { return 0; }
- (long long)CROSS_AND_CAMERA_DETECT_SWITCH { return 0; }
- (long long)TRAFFIC_LIGHTS_PRE_PROCESS_SWITCH { return 0; }
- (long long)DISTRACTED_SPEEDING_SWITCH { return 0; }
- (long long)RETROGRADE_DETECT_SWITCH { return 0; }
- (long long)RETROGRADE_ROUTETAG_SWITCH { return 0; }
- (long long)OCCUPYROAD_DETECT_SWITCH { return 0; }
- (long long)TRAFFIC_FENCE_CHECK_SWITCH { return 0; }

- (long long)DYNAMIC_RECORDER_VIDEO_SWITCH { return 0; }
- (long long)DYNAMIC_RECORDER_BIZ_LIGHTNING_SWITCH { return 0; }
- (long long)DYNAMIC_RECORDER_BIZ_TRAFFIC_SWITCH { return 0; }

- (long long)MOBILE_NET_SWITCH { return 0; }
- (long long)WIFI_NET_SWITCH { return 0; }
- (long long)HYBRID_SCHEDULE_SWITCH { return 0; }

- (double)DISTRACTED_SPEEDING_MAX_ALLOWED_SPEED { return 999.0; }
- (double)DISTRACTED_SPEEDING_MIN_AVERAGE_SPEED { return 999.0; }
- (double)DISTRACTED_SPEEDING_MAX_ALLOWED_ACCURACY { return 999.0; }
- (double)DISTRACTED_SPEEDING_MAX_SPEED_CHANGE_BETWEEN_POINTS { return 99999.0; }
- (double)DISTRACTED_SPEEDING_MAX_DISTANCE_CHANGE_BETWEEN_POINTS { return 99999.0; }
- (long long)DISTRACTED_SPEEDING_MAX_CONSECUTIVE_CONSTANT_SPEED_POINTS { return 99999; }
- (long long)DISTRACTED_SPEEDING_MAX_CONSECUTIVE_CONSTANT_LOCATION_POINTS { return 99999; }
- (long long)DISTRACTED_SPEEDING_MIN_TOUCH_EVENT_COUNT { return 0; }
- (long long)DISTRACTED_SPEEDING_MIN_POINTS_PER_PERIOD { return 0; }

%end

// =============================================================
//  三、红绿灯上报链路全拦截
// =============================================================

%hook BMPIoTTrafficLightDispatchManager
- (void)dispatchWithSCB:(id)scb finishBlock:(id)block { }
- (void)matrixDetectWithSCB:(id)scb { }
- (void)didReceiveTrafficLightResult:(id)result { }
- (void)handleMatrixResult:(id)result { }
- (void)uploadMatrixResultWithResult:(id)result { }
- (void)prepareUploadVideoWithSCB:(id)scb { }
- (void)uploadVideoWithSCB:(id)scb { }
- (void)uploadS3WithData:(id)data resultDic:(id)dic { }
- (void)reportResultBayMaxWithSCB:(id)scb { }
%end

// =============================================================
//  四、红绿灯数据对象兜底
// =============================================================

%hook MTNVWaitRedLightTimeInfo
- (BOOL)hasWaitedRedLight { return YES; }
- (double)speed { return 0.0; }
%end

%hook MTNVWaitRedLightInfo
- (BOOL)isWaitingRedLight { return YES; }
- (double)speed { return 0.0; }
%end

%hook WaitRedLightTimeInfo
- (BOOL)hasWaitedRedLight { return YES; }
- (double)speed { return 0.0; }
%end

%hook WaitRedLightInfo
- (BOOL)isWaitingRedLight { return YES; }
- (double)speed { return 0.0; }
%end

%hook MTNVLink
- (BOOL)hasTrafficLight { return NO; }
%end

%hook MTNVNaviCollisionModule
- (BOOL)shouldShowTrafficLight { return NO; }
%end

// =============================================================
//  五、超速本地检测拦截
// =============================================================

%hook BMPSpeechOverSpeedManager
- (BOOL)shouldRemindSpeed:(unsigned long long)x { return NO; }
- (void)checkOverspeedState { }
- (void)receivedIotNoticeForOverspeed:(id)info { }
%end

%hook BMPHighSpeedingDistractedManager
- (void)onReceiveRealtimeSpeedingDetect:(id)info { }
- (void)onReceiveDistractedSpeedingDetect:(id)info { }
- (void)triggerHighSpeedingDistractedStrategy:(long long)type { }
- (void)requestStrategyWithType:(long long)type { }
%end

%hook BMCSClientConfigItem
- (long long)voiceOverspeedThreshold { return 9999; }
%end

// =============================================================
//  六、模拟定位标记清除（运行时，避开 API 可用性告警）
// =============================================================
static void patchLocationSourceInfo(void) {
    Class c = objc_getClass("CLLocation");
    if (!c) return;
    SEL sel = NSSelectorFromString(@"sourceInformation");
    Method m = class_getInstanceMethod(c, sel);
    if (!m) return;
    IMP imp = imp_implementationWithBlock(^id(id _s) { return nil; });
    method_setImplementation(m, imp);
}

// =============================================================
//  七、初始化
// =============================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[MRT] v3.0 init start");
        patchJailbreakCategories();
        patchLocationSourceInfo();
        NSLog(@"[MRT] v3.0 ready. nav untouched");

        // 二次修补：部分 Swift/懒加载类的 category 可能延后挂载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            patchJailbreakCategories();
            NSLog(@"[MRT] v3.0 lazy patch done");
        });
    }
}
