TARGET := iphone:clang:latest:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = MeituanRiderTweak
MeituanRiderTweak_FILES = Tweak.xm

MeituanRiderTweak_CFLAGS = -fobjc-arc \
    -Wno-unused-function \
    -Wno-deprecated-declarations \
    -Wno-nullability-completeness \
    -Wno-unused-variable

MeituanRiderTweak_FRAMEWORKS = Foundation UIKit CoreLocation
MeituanRiderTweak_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk
