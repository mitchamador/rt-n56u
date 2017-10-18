#!/bin/bash
SRC=trunk/linux-3.4.x/arch/mips/rt2880/pci.c

git diff --exit-code $SRC >/dev/null || git checkout $SRC

patch --strip 0 <<EOF
--- $SRC
+++ $SRC
@@ -620,7 +620,7 @@ int __init init_ralink_pci(void)
 	pcie_link_status = 0;
 	val = RALINK_PCIE0_RST | RALINK_PCIE1_RST | RALINK_PCIE2_RST;
 	ASSERT_SYSRST_PCIE(val);			// raise reset all PCIe ports
-	udelay(100);
+	udelay(200);
 #if defined (GPIO_PERST)
 	val = RALINK_GPIOMODE;
 	val &= ~((0x3<<PCIE_SHARE_PIN_SW) | (0x3<<UARTL3_SHARE_PIN_SW));
@@ -636,9 +636,9 @@ int __init init_ralink_pci(void)
 #if defined (CONFIG_PCIE_PORT2)
 	val |= (0x1<<GPIO_PCIE_PORT2);
 #endif
-	mdelay(50);
+	mdelay(100);
 	RALINK_GPIO_CTRL0 |= val;			// switch PERST_N pin to output mode
-	mdelay(50);
+	mdelay(100);
 	RALINK_GPIO_DATA0 &= ~(val);			// fall PERST_N pin (reset peripherals)
 #else /* !defined (GPIO_PERST) */
 	RALINK_GPIOMODE &= ~(0x3<<PCIE_SHARE_PIN_SW);	// fall PERST_N pin (reset peripherals)
@@ -670,7 +670,7 @@ int __init init_ralink_pci(void)
 #endif
 	RALINK_CLKCFG1 = val;				// enable clock for needed PCIe ports
 
-	mdelay(10);
+	mdelay(50);
 
 	if ((ralink_asic_rev_id & 0xFFFF) == 0x0101) // MT7621 E2
 		bypass_pipe_rst();
@@ -762,7 +762,7 @@ int __init init_ralink_pci(void)
 #endif
 
 	/* wait before detect card in slots */
-	mdelay(500);
+	mdelay(1000);
 
 #if defined (CONFIG_RALINK_MT7621)
 #if defined (CONFIG_PCIE_PORT0)
EOF
