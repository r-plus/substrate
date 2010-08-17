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
	$(gcc) $(flags) -dynamiclib -o $@ $(filter %.mm,$^) $(filter %.cpp,$^) -install_name /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate -undefined dynamic_lookup -framework CoreFoundation -lobjc
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
	mkdir -p mobilesubstrate/Library/Frameworks/CydiaSubstrate.framework/Headers
	cp -a MobileSafety.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobilePaper.png mobilesubstrate/Library/MobileSubstrate
	cp -a MobileSubstrate.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobileLoader.dylib mobilesubstrate/Library/MobileSubstrate
	mkdir -p mobilesubstrate/usr/include
	cp -a CydiaSubstrate.h mobilesubstrate/Library/Frameworks/CydiaSubstrate.framework/Headers
	ln -s /Library/Frameworks/CydiaSubstrate.framework/Headers/CydiaSubstrate.h mobilesubstrate/usr/include/substrate.h
	mkdir -p mobilesubstrate/usr/lib
	cp -a libsubstrate.dylib mobilesubstrate/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
	ln -s /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate mobilesubstrate/usr/lib/libsubstrate.dylib
	dpkg-deb -b mobilesubstrate mobilesubstrate_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

install: MobileSubstrate.dylib MobileLoader.dylib libsubstrate.dylib
	mkdir -p /Library/MobileSubstrate/DynamicLibraries
	rm -rf /Library/Frameworks/CydiaSubstrate.framework
	mkdir -p /Library/Frameworks/CydiaSubstrate.framework/Versions/A/Headers
	mkdir -p /Library/Frameworks/CydiaSubstrate.framework/Versions/A/Resources
	cp -a MobileSubstrate.dylib /Library/Frameworks/CydiaSubstrate.framework
	ln -fs /Library/Frameworks/CydiaSubstrate.framework/MobileSubstrate.dylib /Library/MobileSubstrate
	cp -a MobileLoader.dylib /Library/Frameworks/CydiaSubstrate.framework
	cp -a libsubstrate.dylib /Library/Frameworks/CydiaSubstrate.framework/Versions/A/CydiaSubstrate
	cp -a CydiaSubstrate.h /Library/Frameworks/CydiaSubstrate.framework/Versions/A/Headers
	ln -s A /Library/Frameworks/CydiaSubstrate.framework/Versions/Current
	ln -s Versions/Current/Resources /Library/Frameworks/CydiaSubstrate.framework
	ln -s Versions/Current/CydiaSubstrate /Library/Frameworks/CydiaSubstrate.framework
	ln -s Versions/Current/Headers /Library/Frameworks/CydiaSubstrate.framework

.PHONY: all clean package
