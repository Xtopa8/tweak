// =============================================================
//  MeituanRiderTweak.xm   v1.1
//  目标：美团众包 iOS (banma_iOS_crowdsource) 13.7.9
//  平台：iOS 16.3 arm64 / TrollStore + TrollFools 注入
//
//  本版本【不修改】任何定位原始数据：
//    ✗ 不改 CLLocation.speed
//    ✗ 不改 CLLocation.horizontalAccuracy
//  → 导航引擎读到真实数据，不会偏航
//
//  功能：
//    1. 越狱检测绕过（OC 层，9 个类）
//    2. 红绿灯采集关闭 + 上传拦截
//    3. 模拟定位标记清除
//
//  说明：不依赖 CydiaSubstrate / substrate.h，仅用 Logos，
//        TrollFools 注入后可正常工作。
// =============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

// =============================================================
//  一、越狱检测绕过（Objective-C 层）
// =============================================================

%hook BMCSJailbreakManager
- (BOOL)bmcs_isJailbreak { return NO; }
- (NSArray *)localForbiddenDylibs { return @[]; }
- (NSArray *)jailbreakDylibs { return @[]; }
%end

%hook BMPSecurityServiceImpl
- (BOOL)bmp_isJailbreak { return NO; }
- (BOOL)appIsJailbroken { return NO; }
%end

%hook CIPFJailBreak
- (BOOL)cipf_isJailBreak { return NO; }
- (BOOL)cipf_isAppJailBreak { return NO; }
%end

%hook SAKFJailBreak
- (BOOL)sakf_isJailBreak { return NO; }
%end

%hook MPCPaymentJailBreak
- (BOOL)mpc_isJailBreak { return NO; }
%end

%hook NVJailbrokenChecker
- (BOOL)checkJailBreak { return NO; }
- (BOOL)deviceIsJailbroken { return NO; }
%end

%hook BMPOperationJailbreakRootCheck
- (BOOL)isJailBroken { return NO; }
- (NSString *)readJailBreakFile { return nil; }
- (void)reportJailbrokenAsynDegrade { }
%end

%hook BMCSJailBreakLimitGrabWaybill
- (BOOL)checkJailBreakLimitGrab:(id)arg { return YES; }
%end

// =============================================================
//  二、红绿灯：关闭采集 + 拦截上传
// =============================================================

%hook NaviTrafficLight
- (BOOL)hasTrafficLight { return NO; }
%end

%hook BMPIoTTrafficLightDispatchManager
- (void)uploadTrafficLightsAsyncVideo:(id)v videoKeyList:(id)l fps:(id)f
                              success:(id)s failure:(id)fl {
    // 空实现：不产生红绿灯上报
}
%end

// =============================================================
//  三、模拟定位标记清除（不影响导航）
// =============================================================

%hook CLLocation
- (CLLocationSourceInformation *)sourceInformation API_AVAILABLE(ios(15.0)) { return nil; }
%end

// =============================================================
//  四、初始化：动态兜底 swizzle
// =============================================================
static void swizzleBooleans(NSArray *classes, NSArray *sels, BOOL value) {
    for (NSString *cn in classes) {
        Class c = objc_getClass(cn.UTF8String);
        if (!c) continue;
        for (NSString *sn in sels) {
            SEL sel = NSSelectorFromString(sn);
            Method m = class_getInstanceMethod(c, sel);
            if (!m) continue;
            IMP fake = imp_implementationWithBlock(^BOOL(id _self) { return value; });
            method_setImplementation(m, fake);
        }
    }
}

%ctor {
    @autoreleasepool {
        NSLog(@"[MeituanRiderTweak] v1.1 loading...");

        // 越狱检测兜底
        swizzleBooleans(@[@"NSObject",
                          @"BMCSJailbreakManager",
                          @"BMPOperationJailbreakRootCheck"],
                        @[@"dp_appIsJailbroken",
                          @"fake_isJailbreak",
                          @"isJailBroken",
                          @"bmcs_isJailbreak"],
                        NO);

        // 红绿灯采集关闭
        swizzleBooleans(@[@"MTNVWaitRedLightInfo",
                          @"WaitRedLightInfo",
                          @"MTNVWaitRedLightTimeInfo",
                          @"WaitRedLightTimeInfo",
                          @"MTNVTrafficLightCountdownInfo",
                          @"TrafficLightCountdownInfo",
                          @"NaviTrafficLight"],
                        @[@"hasTrafficLight",
                          @"shouldShowTrafficLight"],
                        NO);

        NSLog(@"[MeituanRiderTweak] v1.1 loaded. Navigation untouched.");
    }
}
