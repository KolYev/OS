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
    volatile auto* const vga = reinterpret_cast<volatile uint16_t*>(0xB8000);

    for (uint32_t index = 0; index < sizeof(VgaMessage) - 1; ++index)
    {
        vga[index] = MakeVgaCell(VgaMessage[index], color);
    }

    SerialInit();
    uint32_t vga_index = 80;

    for (;;)
    {
        uint8_t scancode = ReadKeyboardByte();

        if (!(scancode & 0x80))
        {
            char character = '?';
            if (scancode == 0x1E) character = 'A';
            else if (scancode == 0x30) character = 'B';

            if (vga_index < 80 * 25)
            {
                vga[vga_index] = MakeVgaCell(character, color);
                vga_index++;
            }

            SerialWriteByte(scancode);
        }
    }
}
