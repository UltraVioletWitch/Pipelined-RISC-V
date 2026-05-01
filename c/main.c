#include <stdint.h>

#define GPIO_DIR ((volatile uint16_t *)0xF0000008)
#define GPIO_OUT ((volatile uint16_t *)0xF0000004)
#define GPIO_IN ((volatile uint16_t *)0xF0000000)

int main() {
    *GPIO_DIR = 0x3FF;
    volatile int z = 0;
    while (1) {
        asm volatile ("mv x9, %0" :: "r"(z));
        volatile int i = 0;
        while (i < 0xFFFFF) {
            i++;
        }
        z++;
        *GPIO_OUT = z;
    }
}
