# A toolchain file, not -D flags: ssplit builds PCRE2 as an ExternalProject that only receives
# CMAKE_TOOLCHAIN_FILE. IOS_SDK (iphoneos | iphonesimulator) comes from the environment for the same reason.
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 17.0)
if(NOT DEFINED ENV{IOS_SDK})
  message(FATAL_ERROR "set IOS_SDK to iphoneos or iphonesimulator")
endif()
set(CMAKE_OSX_SYSROOT $ENV{IOS_SDK})
set(CMAKE_SYSTEM_PROCESSOR arm64)
# ruy's bundled cpuinfo only recognises iOS through ios-cmake's variables (else cpuinfo_arm_mach_init is missing).
set(IOS TRUE)
set(IOS_ARCH arm64)
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO)
set(CMAKE_MACOSX_BUNDLE OFF)
