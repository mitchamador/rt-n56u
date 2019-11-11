# load boards config and template

cd rt-n56u/trunk
#xiaomi mi-r3g
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-board_config.sh -O - | bash -s -- MI-R3G
#newifi d2
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-board_config.sh -O - | bash -s -- NEWIFI-D2

# cpu frequency

cd rt-n56u/trunk
#set kernel cpu freq
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-mt7621_set_cpufreq.sh -O - | bash -s -- 1100
#compile m7621_cpufreq for setting cpu freq from userspace. run m7621_cpufreq xxx, where xxx - desired freq (mhz)
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-mt7621_cpufreq.sh -O - | bash 

or

cd rt-n56u/trunk
wget https://github.com/mitchamador/rt-n56u/raw/master/mt7621_cpufreq.c -O - | ../toolchain-mipsel/toolchain-3.4.x/bin/mipsel-linux-uclibc-gcc -s -x c -o romfs/sbin/mt7621_cpufreq - && make romfs image

# vlmcsd && more (precompiled binaries)

cd rt-n56u
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-kms+intellij.sh && chmod +x rt-n56u-kms+intellij.sh && ./rt-n56u-kms+intellij.sh

add to .config

### Include KMS emulator
CONFIG_FIRMWARE_INCLUDE_KMS=y

### Include Intellij IDEA License Server
CONFIG_FIRMWARE_INCLUDE_INTELLIJ_IDEA_LICENSE_SERVER=y

# wifi krack patch

cd rt-n56u/trunk
wget -q https://raw.githubusercontent.com/mitchamador/rt-n56u/master/rt-n56u-kms+intellij.sh -O - | bash

