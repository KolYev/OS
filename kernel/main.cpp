#include <intrin.h>
#include <stdint.h>

extern "C" void SerialInit();
extern "C" void SerialWriteByte(uint8_t value);

namespace
{
    constexpr char VgaMessage[] = "Hello World!";

    constexpr uint16_t MakeVgaCell(char character, uint8_t color)
    {
        return static_cast<uint16_t>(static_cast<uint8_t>(character))
            | (static_cast<uint16_t>(color) << 8);
    }

    void WriteSerial(const char* text)
    {
        while (*text != '\0')
        {
            SerialWriteByte(static_cast<uint8_t>(*text));
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
    WriteSerial("\r\nKernelMain reached successfully.\r\n");

    for (;;)
    {
        __halt();
    }
}
