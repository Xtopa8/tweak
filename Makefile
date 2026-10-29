TARGET := iphone:clang:latest:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MeituanRiderTweak
MeituanRiderTweak_FILES = Tweak.xm

MeituanRiderTweak_CFLAGS = -fobjc-arc \
    -Wno-unused-function \
    -Wno-deprecated-declarations \
    -Wno-nullability-completeness \
    -Wno-unused-variable

MeituanRiderTweak_FRAMEWORKS = Foundation UIKit CoreLocation

# 强制产出标准 MH_DYLIB（带 LC_ID_DYLIB），TrollFools 的 ldid 才能识别
MeituanRiderTweak_LDFLAGS = -install_name @executable_path/Frameworks/MeituanRiderTweak.dylib

include $(THEOS_MAKE_PATH)/tweak.mk
