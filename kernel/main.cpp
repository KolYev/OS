#include <intrin.h>
#include <stdint.h>

extern "C" void SerialInit();
extern "C" void SerialWriteByte(uint8_t value);
extern "C" uint8_t ReadKeyboardByte();

namespace
{
    constexpr char VgaMessage[] = "Hello World";

    constexpr uint16_t MakeVgaCell(char character, uint8_t color)
    {
        return static_cast<uint16_t>(static_cast<uint8_t>(character))
            | (static_cast<uint16_t>(color) << 8);
    }

    // Функция для отправки строки в последовательный порт
    void WriteSerial(const char* text) 
    {
        while (*text != '\0')
        {
            SerialWriteByte(static_cast<uint8_t>(*text)); // отправляет текущий символ
            ++text;
        }
    }
}

extern "C" [[noreturn]] void KernelMain()
{
    constexpr uint8_t color = 0x0F;
    constexpr char Keyboard[] = {
        'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']',
        'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';',
        'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/'
    };
    constexpr uint8_t scancodes[] = {
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
        0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
        0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35
    };

    volatile auto* const vga = reinterpret_cast<volatile uint16_t*>(0xB8000);

    for (uint32_t index = 0; index < sizeof(VgaMessage) - 1; ++index)
    {
        vga[index] = MakeVgaCell(VgaMessage[index], color);
    }

    SerialInit();
    uint32_t vga_index = 80;
    uint8_t keyboard_size = sizeof(Keyboard) / sizeof(Keyboard[0]);

    for (;;)
    {
        uint8_t scancode = ReadKeyboardByte();

        if (!(scancode & 0x80))
        {
            char character = '?';
            
            for (uint8_t i = 0; i < keyboard_size; ++i)
            {
                if (scancode == scancodes[i]) character = Keyboard[i];
            }
            

            if (vga_index < 80 * 25)
            {
                vga[vga_index] = MakeVgaCell(character, color);
                vga_index++;
            }

            SerialWriteByte(scancode);
        }
    }
}
