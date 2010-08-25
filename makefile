flags := 

flags += -I. -isystem extra
flags += -g0 -O2
flags += -Wall #-Werror

flags += -fno-exceptions

flags += -fmessage-length=0
#flags += -fvisibility=hidden

all := libsubstrate.dylib MobileLoader.dylib MobileSubstrate.dylib
all += postrm extrainst_ MobileSafety.dylib

gcc := /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/g++
ldid := ./ldid.sh

ios := 3.2

armv6_flags += -mcpu=arm1176jzf-s
armv6_flags += -miphoneos-version-min=$(ios)
armv6_flags += -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(ios).sdk

armv6_flags := -arch armv6 $(foreach flag,$(armv6_flags),-Xarch_armv6 $(flag))
all_flags := -arch ppc -arch i386 -arch x86_64 $(armv6_flags)

armv6_flags += $(flags)
all_flags += $(flags)

all: $(all)

clean:
	rm -f $(all) Struct.hpp

Struct.hpp:
	$$($(gcc) -print-prog-name=cc1obj) -print-objc-runtime-info </dev/null >$@

libsubstrate.dylib: Hooker.cpp ObjectiveC.mm nlist.cpp Struct.hpp hde64c/include/hde64.h hde64c/src/table64.h hde64c/src/hde64.c Debug.cpp Debug.hpp ARM.hpp
	$(gcc) $(all_flags) -dynamiclib -o $@ $(filter %.mm,$^) $(filter %.cpp,$^) $(filter %.c,$^) -install_name /Library/Frameworks/CydiaSubstrate.framework/Versions/A/CydiaSubstrate -undefined dynamic_lookup -framework CoreFoundation -lobjc -Ihde64c/include
	$(ldid) $@

MobileSubstrate.dylib: Bootstrap.cpp
	$(gcc) $(all_flags) -dynamiclib -o $@ $(filter %.cpp,$^)
	$(ldid) $@

MobileLoader.dylib: Loader.mm
	$(gcc) $(all_flags) -dynamiclib -o $@ $(filter %.mm,$^) -framework CoreFoundation
	$(ldid) $@

MobileSafety.dylib: MobileSafety.mm libsubstrate.dylib CydiaSubstrate.h
	$(gcc) $(armv6_flags) -dynamiclib -o $@ $(filter %.mm,$^) -framework Foundation -lobjc -framework CoreFoundation -L. -lsubstrate -framework UIKit
	$(ldid) $@

%: %.m
	$(gcc) $(armv6_flags) -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc
	$(ldid) $@

package: all
	for arch in ppc i386 arm; do sudo ./package.sh "$${arch}"; done

install: package
	sudo dpkg -i *_$(shell grep ^Version: control | cut -d ' ' -f 2)_$(shell dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null).deb

manual: MobileSubstrate.dylib MobileLoader.dylib libsubstrate.dylib
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
