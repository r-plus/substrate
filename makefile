ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: libsubstrate.dylib MobileSafety.dylib MobileSubstrate.dylib postrm extrainst_

flags := -march=armv6 -mcpu=arm1176jzf-s -g0 -O2 -Wall #-Werror

clean:
	rm -f libsubstrate.dylib postrm extrainst_

libsubstrate.dylib: MobileLoader.mm MobileHooker.mm makefile nlist.cpp
	$(target)gcc $(flags) -fno-exceptions -dynamiclib -o $@ $(filter %.mm,$^) $(filter %.cpp,$^) -install_name /usr/lib/libsubstrate.dylib -undefined dynamic_lookup -framework CoreFoundation -I. -lobjc
	ldid -S $@

MobileSafety.dylib: MobileSafety.mm makefile libsubstrate.dylib
	$(target)gcc $(flags) -fno-exceptions -dynamiclib -o $@ $(filter %.mm,$^) -framework Foundation -lobjc -framework CoreFoundation -L. -lsubstrate -I. -framework UIKit
	ldid -S $@

%: %.m makefile
	$(target)gcc $(flags) -g0 -O2 -Wall -Werror -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc
	ldid -S $@

package:
	rm -rf mobilesubstrate
	mkdir -p mobilesubstrate/DEBIAN
	cp -a control extrainst_ postrm mobilesubstrate/DEBIAN
	mkdir -p mobilesubstrate/Library/MobileSubstrate/DynamicLibraries
	cp -a MobileSafety.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobilePaper.png mobilesubstrate/Library/MobileSubstrate
	#cp -a MobileUnions.dylib mobilesubstrate/Library/MobileSubstrate
	ln -s /usr/lib/libsubstrate.dylib mobilesubstrate/Library/MobileSubstrate/MobileSubstrate.dylib
	mkdir -p mobilesubstrate/usr/include
	cp -a substrate.h mobilesubstrate/usr/include
	mkdir -p mobilesubstrate/usr/lib
	cp -a libsubstrate.dylib mobilesubstrate/usr/lib
	dpkg-deb -b mobilesubstrate mobilesubstrate_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

.PHONY: all clean package
