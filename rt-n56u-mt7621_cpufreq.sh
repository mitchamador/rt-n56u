#!/bin/bash

error(){ # Выход при ошибке
	echo -e "ERROR: $@" >&2
	exit 1
}

# Полный путь к сценарию
script="$(
	cd $(dirname $0)
	echo $(pwd)/$(basename $0) )"

# Определяем каталог с деревом исходных кодов
if [ -d "rt-n56u" ]
then # Если каталог дерева в текущем каталоге
	gitdir="$(
		cd "rt-n56u"
		git rev-parse --show-toplevel 2>/dev/null
	)"
else # Если сценарий запущен изнутри дерева исходников
	gitdir="$(git rev-parse --show-toplevel 2>/dev/null)"
fi
[ -z "$gitdir" ] && gitdir="$( # Если сценарий лежит в дереве исходников
	cd "$(dirname $script)"
	git rev-parse --show-toplevel 2>/dev/null
)"
[ -z "$gitdir" ] && error "Source tree not found.
Put this script into the source tree and try to start again."

# Заходим в trunk
trunkdir="$gitdir/trunk"
cd $trunkdir || error "Path $trunkdir not found"

mkdir -p user/mt7621_cpufreq
echo "download source code"
wget -q https://github.com/mitchamador/rt-n56u/raw/master/mt7621_cpufreq.c -O user/mt7621_cpufreq/mt7621_cpufreq.c

echo "create Makefile"
cat >user/mt7621_cpufreq/Makefile << \EOF
PROG = mt7621_cpufreq

$(PROG): mt7621_cpufreq.c
	$(CC) -o $@ $^ $(CFLAGS) $(DEFINES) $(LIBS)

strip: $(PROG)
	$(STRIP) -s $(PROG)

clean:
	rm -f *.o $(PROG)

romfs:
	$(ROMFSINST) /sbin/$(PROG)
EOF

echo "patching Makefile"
patch --strip 1 <<\EOF
diff --git a/user/Makefile b/user/Makefile
index edeea03..d2ff68e 100644
--- a/user/Makefile
+++ b/user/Makefile
@@ -116,6 +116,10 @@ ifdef CONFIG_BLK_DEV_SD
 dir_$(CONFIG_FIRMWARE_INCLUDE_HDPARM)		+= hdparm
 endif
 
+ifeq ($(CONFIG_PRODUCT),MT7621)
+dir_y						+= mt7621_cpufreq
+endif
+
 ifdef CONFIG_USB_SUPPORT
 dir_y						+= p910nd
 dir_y						+= usb-modeswitch
EOF

exit
