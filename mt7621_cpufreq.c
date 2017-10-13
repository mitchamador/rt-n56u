#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#define handle_error(msg) \
           do { perror(msg); exit(EXIT_FAILURE); } while (0)

#define RALINK_SYSCTL_BASE		0x1E000000
#define RALINK_MEMCTRL_BASE		0x1E005000

#define CPU_MIN_FREQ 600
#define CPU_MAX_FREQ 1400

int ralink_asic_rev_id;

int main(int argc, char *argv[])
{
    const char *vendor_name, *ram_type = "SDRAM";
    char asic_id[8];
    int xtal = 40;
    unsigned int reg, ocp_freq, mips_cpu_feq, surfboard_sysclk;
    char clk_sel;
    char clk_sel2;
    int cpu_fdiv = 0;
    int cpu_ffrac = 0;
    int fbdiv = 0;

    void *ptr, *ptr2;

    unsigned int freq = 0, mult = 0 ;
    if(argc > 1) {
        freq = atoi(argv[1]);
    }

    int mem;
    /* Open /dev/mem */
    if ((mem = open ("/dev/mem", O_RDWR | O_SYNC)) == -1)
        handle_error("Cannot open /dev/mem");

    ptr = mmap (NULL, 0x100, PROT_READ | PROT_WRITE, MAP_SHARED, mem, RALINK_SYSCTL_BASE);
    if(ptr == MAP_FAILED) {
        handle_error("mmap");
    }

    ptr2 = mmap (NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, mem, RALINK_MEMCTRL_BASE);
    if(ptr2 == MAP_FAILED) {
        handle_error("mmap");
    }

    reg = (*((volatile unsigned int *)(ptr + 0x00)));
    memcpy(asic_id, &reg, 4);
    reg = (*((volatile unsigned int *)(ptr + 0x04)));
    memcpy(asic_id+4, &reg, 4);
    asic_id[6] = '\0';
    asic_id[7] = '\0';

    ralink_asic_rev_id = (*((volatile unsigned int *)(ptr + 0x0c)));

    if (strcmp(asic_id, "MT7621") != 0) {
        printf("mt7621 soc not found\n");
        exit(0);
    }

    /* CORE_NUM [17:17], 0: Single Core (S), 1: Dual Core (A) */
    if (ralink_asic_rev_id & (1UL<<17))
        asic_id[6] = 'A';
    else
        asic_id[6] = 'S';

    reg = (*((volatile unsigned int *)(ptr + 0x10)));
    clk_sel = 0;	/* GPLL (500MHz) */
    clk_sel2 = (reg>>4) & 0x03;
    reg = (reg >> 6) & 0x7;
    if (reg >= 6)
        xtal = 25;
    else if (reg <= 2)
        xtal = 20;
    reg = (*((volatile unsigned *)(ptr + 0x2C)));
    if (reg & (0x1UL << 30))
        clk_sel = 1;	/* CPU PLL */

    switch(clk_sel) {
    case 0: /* GPLL (500MHz) */
        reg = (*(volatile unsigned int *)(ptr + 0x44));
        cpu_fdiv = ((reg >> 8) & 0x1F);
        cpu_ffrac = (reg & 0x1F);
        mips_cpu_feq = (500 * cpu_ffrac / cpu_fdiv) * 1000 * 1000;
        break;
    case 1: /* CPU PLL */
        if (freq > 0) {
            if (freq < CPU_MIN_FREQ || freq > CPU_MAX_FREQ) {
                printf("cpu frequency not in range %d-%dMhz\n", CPU_MIN_FREQ, CPU_MAX_FREQ);
            } else {
                mult = freq / (xtal == 25 ? 25 : 20);
            }
        }

        if (mult != 0) {
            printf("trying to set cpu frequency: %dMhz\n", mult * (xtal == 25 ? 25 : 20));

            reg = (*(volatile unsigned int *)(ptr2 + 0x648));
            reg &= ~(0x7ff);
            reg |=  ((mult - 1) << 4) | 0x2;

            (*((volatile unsigned int *)(ptr2 + 0x648))) = reg;
            usleep(10);
        }

        reg = (*(volatile unsigned int *)(ptr2 + 0x648));
        fbdiv = ((reg >> 4) & 0x7F) + 1;
        mips_cpu_feq = (xtal == 25 ? 25 : 20) * fbdiv * 1000 * 1000;	/* 25Mhz Xtal */
        break;
    }

    if (clk_sel2 & 0x01)
        ram_type = "DDR2";
    else
        ram_type = "DDR3";
    if (clk_sel2 & 0x02)
        ocp_freq = mips_cpu_feq/4;	/* OCP_RATIO 1:4 */
    else
        ocp_freq = mips_cpu_feq/3;	/* OCP_RATIO 1:3 */
    surfboard_sysclk = mips_cpu_feq/4;


    munmap(ptr2, 0x1000);
    munmap(ptr, 0x100);

    vendor_name = "MediaTek";

    printf("%s SoC: %s, RevID: %04X, RAM: %s, XTAL: %dMHz\n",
           vendor_name,
           asic_id,
           ralink_asic_rev_id & 0xffff,
           ram_type,
           xtal
          );

    printf("CPU/OCP/SYS frequency: %d/%d/%d MHz\n",
           mips_cpu_feq / 1000 / 1000,
           ocp_freq / 1000 / 1000,
           surfboard_sysclk / 1000 / 1000
          );

    return 0;
}
