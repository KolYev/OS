# OS — x86-64 с нуля в Visual Studio

Стартовый проект загружается через Legacy BIOS, самостоятельно переходит из
16-битного real mode в 64-битный long mode и запускает freestanding-ядро,
собранное MSVC и MASM. Готовый загрузчик и операционная система не используются.

## Быстрый старт

1. Откройте `OS.slnx` в Visual Studio 2026.
2. Выберите `Debug | x64`.
3. Нажмите `Build Solution` (`Ctrl+Shift+B`).
4. Нажмите `F5`, чтобы пересобрать образ и запустить VM `OS-Dev` в VirtualBox.

Первая сборка автоматически загружает UASM 2.57 в `tools\uasm`. Если VirtualBox
не установлен, выполните из PowerShell:

```powershell
.\tools\bootstrap.ps1 -InstallVirtualBox
```

Запуск без Visual Studio:

```powershell
& 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe' `
  .\OS.slnx /m /p:Configuration=Debug /p:Platform=x64
.\run-vbox.ps1 -Image .\build\Debug\os.img
```

## Добавление исходных файлов

- C и C++: сохраняйте `.c`/`.cpp` в `kernel\` или его подпапки.
- x64 MASM: сохраняйте `.asm` в `kernel\` или его подпапки.
- Код BIOS-загрузчика находится в `boot\` и собирается UASM в MASM-синтаксисе.

MSBuild использует рекурсивные wildcard-пути, поэтому новые файлы ядра попадут
в следующую сборку автоматически. Если Solution Explorer ещё не показывает
файл, включите `Show All Files`; вручную добавлять файл в проект не требуется.

## Результаты сборки

Для каждой конфигурации создаются:

- `build\<Configuration>\kernel.exe` — freestanding PE32+ ядро;
- `stage1.bin` и `stage2.bin` — загрузочные стадии;
- `os.img` — 16-МиБ raw disk image;
- `os.vdi` — временная копия для VirtualBox;
- `serial.log` — вывод COM1.

## Текущая схема загрузки

1. BIOS загружает 512-байтный `stage1` по адресу `0x7C00`.
2. `stage1` читает зарезервированные 64 сектора `stage2`.
3. `stage2` читает ядро, включает A20, строит GDT и разбирает PE32+ секции.
4. Создаются identity-mapped 2-МиБ страницы для первого 1 ГиБ.
5. Процессор переходит в long mode и вызывает `KernelEntry`/`KernelMain`.

Стартовый layout намеренно прост: файловой системы пока нет, ядро расположено
в фиксированной области диска, его максимальный PE-файл ограничен 448 КиБ, а
отображён только первый 1 ГиБ памяти. Это следующие подсистемы для развития,
а не ограничения Visual Studio.
