ARCHS = armv7
TARGET = iphone:clang:6.1:5.0
INSTALL_TARGET_PROCESSES = LegacyAI
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = LegacyAI
LegacyAI_FILES = main.m RPLegacyCompatibility.m RPCharacterStore.m RPChatHistory.m RPClassicTheme.m
LegacyAI_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation QuartzCore
LegacyAI_CFLAGS = -fobjc-arc
LegacyAI_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/application.mk
