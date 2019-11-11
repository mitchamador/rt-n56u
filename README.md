# rt-n56u

cd trunk

wget https://github.com/mitchamador/rt-n56u/raw/master/mt7621_cpufreq.c -O - | ../toolchain-mipsel/toolchain-3.4.x/bin/mipsel-linux-uclibc-gcc -s -x c -o romfs/sbin/mt7621_cpufreq - && make romfs image

# cpu frequency

cd rt-n56u
#set kernel cpu freq
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-mt7621_set_cpufreq.sh -O - | bash -s -- 1100
#compile m7621_cpufreq for setting cpu freq from userspace. run m7621_cpufreq xxx, where xxx - desired freq (mhz)
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-mt7621_cpufreq.sh -O - | bash 

# vlmcsd && more (precompiled binaries)
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-kms+intellij.sh -O - | bash

# wifi krack patch
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-kms+intellij.sh -O - | bash
