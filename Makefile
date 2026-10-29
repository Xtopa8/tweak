TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = banma_iOS_crowdsource

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MeituanRiderTweak
MeituanRiderTweak_FILES = Tweak.xm

MeituanRiderTweak_CFLAGS = -fobjc-arc \
    -Wno-unused-function \
    -Wno-deprecated-declarations \
    -Wno-nullability-completeness \
    -Wno-unused-variable

MeituanRiderTweak_FRAMEWORKS = Foundation UIKit CoreLocation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 banma_iOS_crowdsource || true"
