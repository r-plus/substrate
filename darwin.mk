# Cydia Substrate - Powerful Code Insertion Platform
# Copyright (C) 2008-2011  Jay Freeman (saurik)

# GNU Lesser General Public License, Version 3 {{{
#
# Substrate is free software: you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# Substrate is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Substrate.  If not, see <http://www.gnu.org/licenses/>.
# }}}

ios := -i2.0
mac := -m10.5

flags :=
flags += -O2 -g0

flags += -isystem extra
flags += -fno-exceptions
flags += -fvisibility=hidden

flags_ThreadSpecific := -Xarch_armv6 -marm

all: darwin

darwin: libsubstrate.dylib SubstrateBootstrap.dylib SubstrateLauncher.dylib SubstrateLoader.dylib cynject
ios: darwin

%.t.hpp: %.t.cpp trampoline.sh
	./trampoline.sh $@ $*.dylib $* sed otool lipo nm ./cycc $(ios) $(mac) -o$*.dylib -- -dynamiclib $< -Iinclude -Xarch_armv6 -marm

MachProtect.c MachProtect.h: MachProtect.defs
	mig -arch i386 -server /dev/null -user MachProtect.c -header MachProtect.h $<

MachMemory.o: MachProtect.c MachProtect.h
DarwinInjector.o: Trampoline.t.hpp

%.o: %.cpp
	./cycc $(ios) $(mac) -o$@ -- $(flags) $(flags_$(patsubst %.o,%,$@)) -c -Iinclude $<

libsubstrate.dylib: MachMemory.o Hooker.cpp ObjectiveC.o DarwinFindSymbol.o DarwinInjector.o Debug.o hde64c/src/hde64.c MachMessage.cpp ThreadSpecific.o
	./cycc $(ios) $(mac) -olibsubstrate.dylib -- $(flags) -dynamiclib -lobjc \
	    MachMemory.o Hooker.cpp ObjectiveC.o DarwinFindSymbol.o DarwinInjector.o Debug.o \
	    -Xarch_armv6 MachMessage.cpp -Xarch_armv6 ThreadSpecific.o \
	    -Ihde64c/include -Xarch_i386 hde64c/src/hde64.c -Xarch_x86_64 hde64c/src/hde64.c \
	    -install_name /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate

SubstrateBootstrap.dylib: Bootstrap.cpp
	./cycc $(ios) $(mac) -o$@ -- $(flags) -dynamiclib $^

SubstrateLauncher.dylib: DarwinLauncher.cpp libsubstrate.dylib
	./cycc $(ios) $(mac) -o$@ -- $(flags) -dynamiclib $^

SubstrateLoader.dylib: DarwinLoader.cpp Environment.cpp
	./cycc $(ios) $(mac) -o$@ -- $(flags) -dynamiclib $^ \
	    -framework CoreFoundation

%: %.cpp libsubstrate.dylib
	./cycc $(ios) $(mac) -o$@ -- $(flags) $^
	ldid -Stask_for_pid.xml $@

%: %.mm LaunchDaemons.mm Cydia.mm
	./cycc $(ios) -o$@ -- $(flags) $^ \
	    -framework CoreFoundation -framework Foundation

deb: ios extrainst_ postrm
	./package.sh i386
	./package.sh arm

install: deb
	PATH=/Library/Cydia/bin:/usr/sbin:/usr/bin:/sbin:/bin sudo dpkg -i com.cydia.substrate_$(shell ./version.sh)_cydia.deb

upgrade: all
	sudo cp -a libsubstrate.dylib /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
	sudo cp -a SubstrateBootstrap.dylib /Library/Frameworks/CydiaSubstrate.framework/Libraries
	sudo cp -a SubstrateLauncher.dylib /Library/Frameworks/CydiaSubstrate.framework/Libraries
	sudo cp -a SubstrateLoader.dylib /Library/Frameworks/CydiaSubstrate.framework/Libraries

clean:
	rm -f MachProtect.h MachProtect.c *.o libsubstrate.dylib SubstrateBootstrap.dylib SubstrateLauncher.dylib SubstrateLoader.dylib extrainst_ postrm cynject

test:
	./cycc -i2.0 -m10.5 -oTestSuperCall -- TestSuperCall.mm -framework CoreFoundation -framework Foundation -lobjc libsubstrate.dylib
	arch -i386 ./TestSuperCall
	arch -x86_64 ./TestSuperCall

.PHONY: all clean darwin deb install ios test upgrade
