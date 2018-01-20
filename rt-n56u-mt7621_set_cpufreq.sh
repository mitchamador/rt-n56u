#!/bin/bash
SRC=trunk/linux-3.4.x/arch/mips/rt2880/init.c
FREQ=$1

if [ -z $FREQ ]; then
  echo "set default frequency"
  git diff --exit-code $SRC >/dev/null || git checkout $SRC
  exit
elif [[ ! $FREQ =~ ^[0-9]+$ ]] || [ $FREQ -lt 800 ] || [ $FREQ -gt 1200 ]; then
  echo "not valid cpu frequency (800-1200)"
  exit 1
fi

echo "get source code from git"
git diff --exit-code $SRC >/dev/null || git checkout $SRC

MULT=$( expr $FREQ / 20 - 1)
echo "set cpu frequency to "`expr \( $MULT + 1 \) \* 20`"MHz"
MULT_STR=$( printf "0x%x\n" `expr $MULT \* 16 + 2` )

patch --strip 0 <<EOF
--- $SRC
+++ $SRC
@@ -554,9 +554,9 @@
 	case 1: /* CPU PLL */
 		reg = (*(volatile u32 *)(RALINK_MEMCTRL_BASE + 0x648));
 #if defined(CONFIG_RALINK_MT7621_PLL900)
-		if ((reg & 0xff) != 0xc2) {
-			reg &= ~(0xff);
-			reg |=  (0xc2);
+		if ((reg & 0x7ff) != $MULT_STR) {
+			reg &= ~(0x7ff);
+			reg |=  ($MULT_STR);
 			(*((volatile u32 *)(RALINK_MEMCTRL_BASE + 0x648))) = reg;
 			udelay(10);
 		}
EOF
