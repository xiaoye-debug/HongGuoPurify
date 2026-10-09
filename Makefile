ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Phoenix

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HongGuoPurify
HongGuoPurify_FILES = Tweak.xm
HongGuoPurify_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
HongGuoPurify_FRAMEWORKS = Foundation UIKit
HongGuoPurify_LIBRARIES = substrate

BUNDLE_NAME = HongGuoPurifyPrefs
HongGuoPurifyPrefs_FILES = Prefs/HGRootListController.m
HongGuoPurifyPrefs_CFLAGS = -fobjc-arc
HongGuoPurifyPrefs_FRAMEWORKS = UIKit
HongGuoPurifyPrefs_LDFLAGS = -undefined dynamic_lookup
HongGuoPurifyPrefs_INSTALL_PATH = /Library/PreferenceBundles
HongGuoPurifyPrefs_PLIST = Prefs/Resources/Info.plist

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 Phoenix || true"
