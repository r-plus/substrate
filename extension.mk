ifndef base
base := ..
endif

ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

link := -framework CoreFoundation -framework Foundation -F${PKG_ROOT}/System/Library/PrivateFrameworks -L$(base)/../mobilesubstrate -lsubstrate

all: $(name).dylib $(control)

clean:
	rm -f $(name).dylib

$(name).dylib: Tweak.mm makefile
	$(target)g++ -dynamiclib -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -lobjc -I$(base)/../mobilesubstrate $(link) $(flags)
	ldid -S $@

package: all
	rm -rf package
	mkdir -p package/DEBIAN
	mkdir -p package/Library/MobileSubstrate/DynamicLibraries
	cp -a control $(control) package/DEBIAN
	if [[ -e Tweak.plist ]]; then cp -a Tweak.plist package/Library/MobileSubstrate/DynamicLibraries/$(name).plist; fi
	$(MAKE) extra
	cp -a $(name).dylib package/Library/MobileSubstrate/DynamicLibraries
	dpkg-deb -b package $(shell grep ^Package: control | cut -d ' ' -f 2-)_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

extra:

%: %.mm
	$(target)g++ -o $@ -Wall -Werror $< -lobjc -framework CoreFoundation -framework Foundation

.PHONY: all clean extra package
