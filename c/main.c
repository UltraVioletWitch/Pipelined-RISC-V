#include <stdint.h>

#define GPIO_BASE 0xF0000000UL
#define GPIO_IN (*(volatile uint32_t *)(GPIO_BASE + 0x00))
#define GPIO_OUT (*(volatile uint32_t *)(GPIO_BASE + 0x04))
#define GPIO_DIR (*(volatile uint32_t *)(GPIO_BASE + 0x08))
#define GPIO_IE (*(volatile uint32_t *)(GPIO_BASE + 0x0C))
#define GPIO_IP (*(volatile uint32_t *)(GPIO_BASE + 0x10))

#define csr_write(csr, val) __asm__ volatile ("csrw " #csr ", %0" :: "r"(val))
#define csr_set(csr, val)   __asm__ volatile ("csrs " #csr ", %0" :: "r"(val))
#define csr_read(csr, val)  __asm__ volatile ("csrr %0, " #csr : "=r"(val))

#define PIN_OUT  0
#define PIN_IN  10

volatile int toggle = 0;

__attribute__((interrupt("machine"), aligned(4)))
void trap_handler(void) {
    uint32_t mcause;
    csr_read(mcause, mcause);

    if (mcause == 0x8000000BUL) {
        uint32_t pending = GPIO_IP;

        if (pending & (1u << PIN_IN)) {
            toggle = !toggle;

            GPIO_IP = (1u << PIN_IN);
        }
    }
}

int main() {
    GPIO_DIR = 0x3FF;
    GPIO_OUT = 0;
    GPIO_IE = (1u << PIN_IN);
    GPIO_IP = 0xFFFFFFFF;

    csr_write(mtvec, (uint32_t)trap_handler);
    csr_write(mie, 0x800);

    csr_write(mstatus, 0x8);

    int z = 0;
    while (1) {
        if (toggle) {
            z = (z + 1) & 0x3FF;
            GPIO_OUT = z;
        }
        for (volatile int d = 0; d < 0x3FFFF; d++);
    }
}
