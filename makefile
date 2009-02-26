ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: libsubstrate.dylib MobileSafety.dylib MobileSubstrate.dylib postrm preinst

flags := 

clean:
	rm -f libsubstrate.dylib postrm preinst

libsubstrate.dylib: MobileHooker.mm makefile MobileLibrary.cpp
	$(target)gcc $(flags) -fno-exceptions -dynamiclib -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework Foundation -lobjc -framework CoreFoundation -install_name /usr/lib/libsubstrate.dylib
	ldid -S $@

%.dylib: %.mm makefile libsubstrate.dylib MobileLibrary.cpp
	$(target)gcc $(flags) -dynamiclib -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework Foundation -lobjc -framework CoreFoundation -init _MSInitialize -L. -lsubstrate -I. -framework UIKit
	ldid -S $@

%: %.m makefile
	$(target)gcc $(flags) -g0 -O2 -Wall -Werror -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc
	ldid -S $@

package:
	rm -rf mobilesubstrate
	mkdir -p mobilesubstrate/DEBIAN
	cp -a control preinst postrm mobilesubstrate/DEBIAN
	mkdir -p mobilesubstrate/Library/MobileSubstrate/DynamicLibraries
	cp -a MobileSafety.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobilePaper.png mobilesubstrate/Library/MobileSubstrate
	#cp -a MobileUnions.dylib mobilesubstrate/Library/MobileSubstrate
	cp -a MobileSubstrate.dylib mobilesubstrate/Library/MobileSubstrate
	mkdir -p mobilesubstrate/usr/include
	cp -a substrate.h mobilesubstrate/usr/include
	mkdir -p mobilesubstrate/usr/lib
	cp -a libsubstrate.dylib mobilesubstrate/usr/lib
	dpkg-deb -b mobilesubstrate mobilesubstrate_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

.PHONY: all clean package
