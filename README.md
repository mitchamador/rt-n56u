# rt-n56u

cd trunk

wget https://github.com/mitchamador/rt-n56u/raw/master/mt7621_cpufreq.c -O - | ../toolchain-mipsel/toolchain-3.4.x/bin/mipsel-linux-uclibc-gcc -s -x c -o romfs/sbin/mt7621_cpufreq - && make romfs image
