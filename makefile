ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

flags := -I. -g0 -O2 -Wall -isystem extra -fno-exceptions #-Werror
all := libsubstrate.dylib MobileLoader.dylib MobileSubstrate.dylib postrm extrainst_

ifeq (,)
gcc := /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/g++
ldid := true
flags += -arch i386 -arch x86_64
else
gcc := $(target)gcc
ldid := ldid
flags += -march=armv6 -mcpu=arm1176jzf-s 
all += MobileSafety.dyib
endif

all: $(all)

clean:
	rm -f libsubstrate.dylib postrm extrainst_ Struct.hpp

Struct.hpp:
	$$($(gcc) -print-prog-name=cc1obj) -print-objc-runtime-info </dev/null >$@

libsubstrate.dylib: MobileHooker.mm makefile nlist.cpp Struct.hpp disasm.h
	$(gcc) $(flags) -dynamiclib -o $@ $(filter %.mm,$^) $(filter %.cpp,$^) -install_name /usr/lib/libsubstrate.dylib -undefined dynamic_lookup -framework CoreFoundation -lobjc
	$(ldid) $@

MobileSubstrate.dylib: MobileBootstrap.cpp makefile
	$(gcc) $(flags) -dynamiclib -o $@ $(filter %.cpp,$^)
	$(ldid) $@

MobileLoader.dylib: MobileLoader.mm makefile
	$(gcc) $(flags) -dynamiclib -o $@ $(filter %.mm,$^) -framework CoreFoundation
	$(ldid) $@

MobileSafety.dylib: MobileSafety.mm makefile libsubstrate.dylib
	$(gcc) $(flags) -dynamiclib -o $@ $(filter %.mm,$^) -framework Foundation -lobjc -framework CoreFoundation -L. -lsubstrate -framework UIKit
	$(ldid) $@

%: %.m makefile
	$(gcc) $(flags) -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc
	$(ldid) $@

package:
	rm -rf mobilesubstrate
	mkdir -p mobilesubstrate/DEBIAN
	cp -a control extrainst_ postrm mobilesubstrate/DEBIAN
	mkdir -p mobilesubstrate/Library/MobileSubstrate/DynamicLibraries
	cp -a MobileSafety.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobilePaper.png mobilesubstrate/Library/MobileSubstrate
	cp -a MobileSubstrate.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobileLoader.dylib mobilesubstrate/Library/MobileSubstrate
	mkdir -p mobilesubstrate/usr/include
	cp -a substrate.h mobilesubstrate/usr/include
	mkdir -p mobilesubstrate/usr/lib
	cp -a libsubstrate.dylib mobilesubstrate/usr/lib
	dpkg-deb -b mobilesubstrate mobilesubstrate_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

install: MobileSubstrate.dylib MobileLoader.dylib libsubstrate.dylib
	mkdir -p /Library/MobileSubstrate/DynamicLibraries
	cp -a MobileSubstrate.dylib /Library/MobileSubstrate
	cp -a MobileLoader.dylib /Library/MobileSubstrate
	cp -a libsubstrate.dylib /usr/lib

.PHONY: all clean package
