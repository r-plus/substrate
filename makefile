ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: libsubstrate.dylib postrm preinst

clean:
	rm -f libsubstrate.dylib postrm preinst

libsubstrate.dylib: MobileSubstrate.mm makefile
	$(target)g++ -dynamiclib -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework Foundation -init _MSInitialize -lobjc -framework CoreFoundation -install_name /usr/lib/libsubstrate.dylib

%: %.m makefile
	$(target)gcc -g0 -O2 -Wall -Werror -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc

package:
	rm -rf mobilesubstrate
	mkdir -p mobilesubstrate/DEBIAN
	cp -a control preinst postrm mobilesubstrate/DEBIAN
	mkdir -p mobilesubstrate/Library/MobileSubstrate/DynamicLibraries
	ln -s /usr/lib/libsubstrate.dylib mobilesubstrate/Library/MobileSubstrate/MobileSubstrate.dylib
	mkdir -p mobilesubstrate/usr/include
	cp -a substrate.h mobilesubstrate/usr/include
	mkdir -p mobilesubstrate/usr/lib
	cp -a libsubstrate.dylib mobilesubstrate/usr/lib
	dpkg-deb -b mobilesubstrate mobilesubstrate_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

.PHONY: all clean package
