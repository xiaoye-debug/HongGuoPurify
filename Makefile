ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Phoenix

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HongGuoPurify

HongGuoPurify_FILES = Tweak.xm
HongGuoPurify_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
HongGuoPurify_FRAMEWORKS = Foundation UIKit
HongGuoPurify_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Phoenix || true"
