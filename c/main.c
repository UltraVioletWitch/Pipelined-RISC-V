#include <stdint.h>

int main() {
    register int x15 asm("a5");
    x15 = 0x0;
    volatile unsigned int delay;
    while(1) {
        while (x15 < 0xF) {
            delay = 0;
            while (delay < 0xFFFFFF) {
                delay++;
            }
            x15++;
        }

        while (x15 > 0x0) {
            delay = 0;
            while (delay < 0xFFFFFF) {
                delay++;
            }
            x15--;
        }
    }
}
