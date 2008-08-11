ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: MobileSubstrate.dylib postrm preinst

clean:
	rm -f MobileSubstrate.dylib postrm preinst

MobileSubstrate.dylib: MobileSubstrate.mm makefile
	$(target)g++ -dynamiclib -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework Foundation -init _CSInitialize -lobjc -framework CoreFoundation

%: %.m makefile
	$(target)gcc -g0 -O2 -Wall -Werror -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc

package:
	rm -rf mobilesubstrate
	mkdir -p mobilesubstrate/DEBIAN
	mkdir -p mobilesubstrate/Library/MobileSubstrate/DynamicLibraries
	cp -a control preinst postrm mobilesubstrate/DEBIAN
	cp -a MobileSubstrate.dylib ../pledit/pledit mobilesubstrate/Library/MobileSubstrate
	dpkg-deb -b mobilesubstrate mobilesubstrate_0.9.2519-1_iphoneos-arm.deb

.PHONY: all clean package
