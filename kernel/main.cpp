#include <intrin.h>
#include <stdint.h>

extern "C" void SerialInit();
extern "C" void SerialWriteByte(uint8_t value);
extern "C" uint8_t ReadKeyboardByte();

namespace
{
    constexpr uint8_t text_color = 0x0F;
    volatile auto* const vga = reinterpret_cast<volatile uint16_t*>(0xB8000);
    constexpr char message[] = "LawlessnessOS \x8F\xE0\xA8\xA2\xA5\xE2 \xAC\xA8\xE0";

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

    void print(const char text[], uint32_t& cursor_index)
    {
        for (uint32_t index = 0; text[index] != '\0'; ++index)
        {
            if (cursor_index < 80 * 25)
            {
                vga[cursor_index] = MakeVgaCell(text[index], text_color);
                cursor_index++;
            }
        }
    }

}

class UI
{
    void Display()
    {
        for (uint32_t index = 0; index < 80 * 25; ++index)
        {
            if (index > 80 && index < 160 || index >= 80 * 24)
            {
                print("-", index);
                --index;
            }
            else if (index % 80 == 0 && index > 80 || index % 80 == 79 && index > 80)
            {
                print("|", index);
                --index;
            }
        }
    }
public:
    UI()
    {
        Display();
    }
};

extern "C" [[noreturn]] void KernelMain()
{
    constexpr uint8_t Backspace = 0x0E;
    constexpr uint8_t Enter = 0x1C;
    constexpr uint8_t Capslock = 0x3A;

    constexpr char CapsKeyboard[] = {
        'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']',
        'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';',
        'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/',
        ' '
    };

    constexpr char Keyboard[] = {
        'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']',
        'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';',
        'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/',
        ' '
    };

    constexpr uint8_t scancodes[] = {
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
        0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
        0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35,
        0x39
    };

    // стрелки: вверх, вниз, влево, вправо
    constexpr uint8_t arrows[] = {0x48, 0x50, 0x4B, 0x4D};

    uint32_t vga_index = 0;
    print(message, vga_index);
    UI ui;

    SerialInit();
    uint8_t keyboard_size = sizeof(Keyboard) / sizeof(Keyboard[0]);

    bool capslock_pressed = false;

    for (;;)
    {
        uint8_t scancode = ReadKeyboardByte();

        if (!(scancode & 0x80))
        {
            if (scancode == Capslock)
            {
                capslock_pressed = !capslock_pressed;
            }
            else if (scancode == Backspace)
            {
                if (vga_index > 0)
                {
                    vga_index--;
                    vga[vga_index] = MakeVgaCell(' ', text_color);
                }
            }
            else if (scancode == Enter)
            {
                uint32_t row = vga_index / 80;
                if (row < 24)
                {
                    vga_index = (row + 1) * 80;
                }
            }
            else if (scancode == arrows[0])
            {
                vga_index -= 81;

            }
            else if (scancode == arrows[1]) {
                vga_index += 79;
            }
            else if (scancode == arrows[2]) {
                vga_index -= 1;
            }
            else if (scancode == arrows[3]) {
                vga_index += 1;
            }
            else
            {
                char character = '?';

                for (uint8_t i = 0; i < keyboard_size; ++i)
                {
                    if (scancode == scancodes[i]) character = capslock_pressed ? CapsKeyboard[i] : Keyboard[i];
                }


                if (vga_index < 80 * 25)
                {
                    vga[vga_index] = MakeVgaCell(character, text_color);
                    vga_index++;
                }
            }

            SerialWriteByte(scancode);
        }
    }
}
