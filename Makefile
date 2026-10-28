ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Tanhdzcute

COMMON_FLAGS = -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function -Wno-unused-value \
               -I./ -I./il2cpp \
               -Os -flto -fvisibility=hidden -fvisibility-inlines-hidden \
               -fmerge-all-constants -ffunction-sections -fdata-sections \
               -fstack-protector-strong

CXX_FLAGS = -std=c++17 -fno-rtti -DNDEBUG

$(TWEAK_NAME)_CCFLAGS = $(COMMON_FLAGS) $(CXX_FLAGS)
$(TWEAK_NAME)_CFLAGS  = $(COMMON_FLAGS) -fobjc-arc

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText AVFoundation Accelerate GLKit SystemConfiguration GameController Metal MetalKit CoreFoundation CFNetwork

$(TWEAK_NAME)_LIBRARIES = c++

$(TWEAK_NAME)_LDFLAGS = -Wl,-x -Wl,-S -flto -F. -framework JRMemory Other/libdobby_fixed.a 

$(TWEAK_NAME)_FILES = ImGuiDrawView.mm \
                      oxorany/oxorany.cpp \
                      $(wildcard Esp/*.mm) \
                      $(wildcard Esp/*.m) \
                      $(wildcard IMGUI/*.cpp) \
                      $(wildcard IMGUI/*.mm) \
                      $(wildcard Hosts/*.m) \
                      Other/hook.c \
                      Other/mach_excServer.c

include $(THEOS_MAKE_PATH)/tweak.mk