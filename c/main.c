#include <stdint.h>
#include <string.h>

#define GPIO_IN    (*(volatile uint32_t *)0xF0000000)
#define GPIO_OUT   (*(volatile uint32_t *)0xF0000004)
#define GPIO_DIR   (*(volatile uint32_t *)0xF0000008)
#define GPIO_IE   (*(volatile uint32_t *)0xF000000C)
#define GPIO_IP   (*(volatile uint32_t *)0xF0000010)

<<<<<<< HEAD
=======
#define UART_TX   (*(volatile uint32_t *)0xF0001000)
#define UART_RX   (*(volatile uint32_t *)0xF0001004)
#define UART_IP   (*(volatile uint32_t *)0xF0001008)
#define UART_IE   (*(volatile uint32_t *)0xF000100C)

>>>>>>> 9257098 (removed vcd files)
#define MTIME_H    (*(volatile uint32_t *)0xFFFF0000)
#define MTIME_L    (*(volatile uint32_t *)0xFFFF0004)
#define MTIMECMP_H (*(volatile uint32_t *)0xFFFF0008)
#define MTIMECMP_L (*(volatile uint32_t *)0xFFFF000C)

#define write_csr(reg, val) asm volatile("csrw " #reg ", %0" :: "r"(val))
#define set_csr(reg, val)   asm volatile("csrs " #reg ", %0" :: "r"(val))
#define read_csr(reg) ({ uint32_t val; asm volatile("csrr %0, " #reg : "=r"(val)); val; })

// 12MHz clock - 1 second interval
#define TIMER_INTERVAL 12500000ULL

<<<<<<< HEAD
static volatile uint32_t led_state = 0;
static volatile uint32_t tick_count = 0;
static volatile int timerFlag = 0;
=======
#define UART_IP_TX (1<<0)
#define UART_IP_RX (1<<1)

static volatile uint32_t led_state = 0;
static volatile uint32_t tick_count = 0;
static volatile int timerFlag = 0;
static volatile int uartFlag = 0;
static volatile int gpioFlag = 0;

static volatile uint8_t uart_busy = 0;
static volatile uint8_t buf = 0;

void spin(uint64_t time) {
    uint64_t i = 0;
    while (i < time) {
        i++;
    }
}

void uart_putc(char c) {
    while (uart_busy);

    UART_TX = c;
    uart_busy = 1;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}
>>>>>>> 9257098 (removed vcd files)

void set_timer(uint64_t interval) {
    uint32_t lo, hi;
    do {
        hi = MTIME_H;
        lo = MTIME_L;
    } while (MTIME_H != hi);

    uint64_t now  = ((uint64_t)hi << 32) | lo;
    uint64_t next = now + interval;

    MTIMECMP_H = 0xFFFFFFFF;
    MTIMECMP_L = (uint32_t)(next & 0xFFFFFFFF);
    MTIMECMP_H = (uint32_t)(next >> 32);
}

void __attribute__((interrupt("machine"))) trap_handler() {
    uint32_t cause = read_csr(mcause);
    //GPIO_OUT = 0x11;

    if (cause == 0x80000007) {
<<<<<<< HEAD
=======
        // timer interrupt
>>>>>>> 9257098 (removed vcd files)
        timerFlag = 1;
        // reschedule
        set_timer(TIMER_INTERVAL);
    } else if (cause == 0x8000000B) {
<<<<<<< HEAD
        // external interrupt - flash all LEDs twice
        uint32_t saved = led_state;
        for (int i = 0; i < 3; i++) {
            GPIO_OUT = 0x3FF;
            for (volatile int d = 0; d < 5000000; d++);
            GPIO_OUT = 0x00;
            for (volatile int d = 0; d < 5000000; d++);
        }
        GPIO_OUT = saved;
=======

        uint32_t uart_ip = UART_IP;
        uint32_t gpio_ip = GPIO_IP;

        if (uart_ip & UART_IP_RX) {
            buf = (uint8_t)UART_RX;
            uartFlag = 1;
            UART_IP = UART_IP_RX;   // W1C clear
        } else if (uart_ip & UART_IP_TX) {
            uart_busy = 0;
            UART_IP = UART_IP_TX;
        }

        if (gpio_ip) {
            gpioFlag = 1;
            GPIO_IP = 0xFFFF;
        }

>>>>>>> 9257098 (removed vcd files)
        GPIO_IP = 0xFFFF;
    }
}

int main() {
    GPIO_DIR = 0x3FF;
    GPIO_IE  = 0xFC00;
<<<<<<< HEAD
    //GPIO_OUT = 0x55;    // startup pattern so we know code is running

=======

    UART_IE = UART_IP_RX | UART_IP_TX;
>>>>>>> 9257098 (removed vcd files)

    // enable timer and external interrupts
    set_csr(mie, (1 << 7));
    set_csr(mie, (1 << 11));

    // arm the first timer interrupt
    set_timer(TIMER_INTERVAL);
<<<<<<< HEAD
    set_csr(mstatus, (1 << 3));

    // enable global interrupts


    while (1) {
        if (timerFlag) {
            tick_count++;

=======

    // enable global interrupts
    set_csr(mstatus, (1 << 3));

    uart_puts("Hello Computer!\r\n");

    while (1) {

        if (timerFlag) {
            tick_count++;

            // rotate leds
>>>>>>> 9257098 (removed vcd files)
            led_state = (led_state << 1) | (led_state >> 9);
            led_state &= 0x3FF;

            if (led_state == 0)
                led_state = 0x01;
<<<<<<< HEAD

            GPIO_OUT = led_state;

            timerFlag = 0;
        }
=======
            

            GPIO_OUT = led_state & 0x3FF;

            timerFlag = 0;
        }

        if (uartFlag) {
            uart_putc(buf);
            uartFlag = 0;
        }

        if (gpioFlag) {
            // external interrupt - flash all LEDs twice
            uart_puts("EXT IRQ fired\r\n");
            uint32_t saved = led_state;
            for (int i = 0; i < 3; i++) {
                GPIO_OUT = 0x3FF;
                spin(1000000);
                GPIO_OUT = 0x00;
                spin(1000000);
            }
            GPIO_OUT = saved;
            gpioFlag = 0;
        }
>>>>>>> 9257098 (removed vcd files)
    }
}
