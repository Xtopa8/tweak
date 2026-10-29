// =============================================================
//  MeituanRiderTweak.xm   v4.0
//  目标：美团众包 iOS (banma_iOS_crowdsource) 13.7.9
//  平台：iOS 16.3 arm64 / TrollStore + TrollFools
//
//  ===== 与安卓模块的同性质对照 =====
//  安卓(宗师) hook 的类（从 dex 解密得出）：
//    com.meituan.banma.matrix.imagetdetect.hybridschedule.ScheduleControlBlock
//    com.meituan.banma.matrix.imagetdetect.hybridschedule.scheduler.HybridScheduler
//    com.meituan.banma.trafficsafety.model.SpeedingDistractionModel
//    com.meituan.banma.trafficsafety.model.PhoneHolderCheckModel
//    com.meituan.banma.waybill.navi.view.aisafety.*
//    com.meituan.banma.matrix.imagetdetect.*
//
//  iOS 对应：
//    ScheduleControlBlock  -> BMPIoTTrafficLightSCB
//    HybridScheduler       -> BMPIoTTrafficLightSCBManager
//    SpeedingDistraction.. -> BMPHighSpeedingDistractedManager / DataItem
//    PhoneHolderCheckModel -> BMPCaptureShelfCheckManager
//    aisafety.*            -> BMPSpeechOverSpeedManager
//    matrix.imagetdetect.* -> BMPIoTTrafficLightDispatchManager
//
//  ===== 不改定位数据 =====
//  不碰 CLLocation.speed / horizontalAccuracy -> 导航不偏
// =============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

// =============================================================
//  运行时工具：全类扫描替换 selector 实现
// =============================================================
static void swizzleEverywhere(SEL sel, int kind) {
    // kind: 0=BOOL(返回NO) 1=longlong(返回0) 2=id(返回nil)
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    if (!classes) return;
    count = objc_getClassList(classes, count);

    id (^nilBlk)(id) = ^id(id _s) { return nil; };
    BOOL (^boolBlk)(id) = ^BOOL(id _s) { return NO; };
    long long (^llBlk)(id) = ^long long(id _s) { return 0; };

    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!cls) continue;
        Class pairs[2] = { cls, object_getClass(cls) };
        for (int p = 0; p < 2; p++) {
            Class tgt = pairs[p];
            if (!tgt) continue;
            unsigned int mc = 0;
            Method *ms = class_copyMethodList(tgt, &mc);
            if (!ms) continue;
            for (unsigned int j = 0; j < mc; j++) {
                if (method_getName(ms[j]) == sel) {
                    IMP imp = (kind == 2) ? imp_implementationWithBlock(nilBlk)
                            : (kind == 1) ? imp_implementationWithBlock(llBlk)
                                          : imp_implementationWithBlock(boolBlk);
                    method_setImplementation(ms[j], imp);
                }
            }
            free(ms);
        }
    }
    free(classes);
}

// =============================================================
//  一、越狱检测绕过
// =============================================================
static void patchJailbreakCategories(void) {
    swizzleEverywhere(@selector(bmp_isJailbreak),      0);
    swizzleEverywhere(@selector(bmcs_isJailbreak),     0);
    swizzleEverywhere(@selector(cipf_isJailBreak),     0);
    swizzleEverywhere(@selector(cipf_isAppJailBreak),  0);
    swizzleEverywhere(@selector(dp_appIsJailbroken),   0);
    swizzleEverywhere(@selector(sakf_isJailBreak),     0);
    swizzleEverywhere(@selector(mpc_isJailBreak),      0);
    swizzleEverywhere(@selector(fake_isJailbreak),     1);
    swizzleEverywhere(@selector(readJailBreakFile),    2);
}

%hook NVJailbrokenChecker
+ (BOOL)appIsJailbroken { return NO; }
+ (BOOL)deviceIsJailbroken { return NO; }
%end

%hook SAKGuardCommon
+ (BOOL)checkJailBreak { return NO; }
%end

%hook BMPClientConfigManager
+ (id)reportJailbrokenAsynDegrade { return nil; }
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
//  二、关闭 IoT 摄像头检测系统（对应安卓 ScheduleControlBlock 配置）
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
//  三、★ 调度器拦截（对应安卓 HybridScheduler）
//  Android: hook HybridScheduler + ScheduleControlBlock -> 任务不派发
//  iOS    : hook BMPIoTTrafficLightSCBManager          -> 任务不派发
// =============================================================
%hook BMPIoTTrafficLightSCBManager

// 生产检测任务
- (void)produceSCB:(id)scb { }

// 混合模式派发检测（红绿灯/超速/支架 全靠这个入口）
- (void)trafficLightMixDispatchDetectWithVideoId:(id)videoId
                                      countOfDay:(long long)countOfDay
                                            path:(id)path
                                             fps:(double)fps
                                            size:(float)size
                                     collectTime:(double)collectTime
                                             ext:(id)ext { }

// 融合模式派发
- (void)dispatchDetectFusionModeWithVideoId:(id)videoId
                                 countOfDay:(long long)countOfDay
                              originPathTag:(id)originPathTag
                                        fps:(double)fps
                                       size:(float)size
                                collectTime:(double)collectTime
                                        ext:(id)ext { }

%end

// =============================================================
//  四、图像检测与上传拦截（对应安卓 matrix.imagetdetect.*）
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
//  五、支架/手机摆放检测（对应安卓 PhoneHolderCheckModel）
// =============================================================
%hook BMPCaptureShelfCheckManager
- (BOOL)canShelfCheck { return NO; }
- (BOOL)canCheckVisionResults { return NO; }
- (void)capture { }
- (void)startOccCheck:(id)block { }
- (void)uploadCheckResultWithClean:(BOOL)clean { }
%end

// =============================================================
//  六、超速检测（对应安卓 SpeedingDistractionModel + aisafety.*）
//  Android 做法：让模型不产生结果、让播报不触发
//  iOS 同做：检测回调置空 + 语音判定关闭 + 模型 sessionId 清空
// =============================================================

// 6.1 分心+超速检测管理（接收侧）
%hook BMPHighSpeedingDistractedManager
- (void)onReceiveRealtimeSpeedingDetect:(id)info { }
- (void)onReceiveDistractedSpeedingDetect:(id)info { }
- (void)triggerHighSpeedingDistractedStrategy:(long long)type { }
- (void)requestStrategyWithType:(long long)type { }
%end

// 6.2 超速数据模型（对应 SpeedingDistractionModel）
%hook BMPHighSpeedingDistractedDataItem
- (id)sessionId { return nil; }
%end

// 6.3 语音超速播报（对应 aisafety.*）
%hook BMPSpeechOverSpeedManager
- (BOOL)shouldRemindSpeed:(unsigned long long)x { return NO; }
- (void)checkOverspeedState { }
- (void)receivedIotNoticeForOverspeed:(id)info { }
%end

// 6.4 语音超速阈值
%hook BMCSClientConfigItem
- (long long)voiceOverspeedThreshold { return 9999; }
%end

%hook BMPClientConfigManager
+ (id)voiceOverspeedThreshold { return @(9999); }
%end

// =============================================================
//  七、红绿灯判定数据（对应安卓 trafficsafety.model.*）
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
//  八、模拟定位标记（不影响导航）
// =============================================================
static void patchLocationSourceInfo(void) {
    Class c = objc_getClass("CLLocation");
    if (!c) return;
    Method m = class_getInstanceMethod(c, NSSelectorFromString(@"sourceInformation"));
    if (!m) return;
    method_setImplementation(m, imp_implementationWithBlock(^id(id _s) { return nil; }));
}

// =============================================================
//  九、初始化
// =============================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[MRT] v4.0 init start (android-parity build)");
        patchJailbreakCategories();
        patchLocationSourceInfo();
        NSLog(@"[MRT] v4.0 ready: scheduler+tasks blocked, nav untouched");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            patchJailbreakCategories();
            NSLog(@"[MRT] v4.0 lazy patch done");
        });
    }
}
