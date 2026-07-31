; Загрузчик второго этапа. Считывает ядро ​​в формате PE32+, отображает его секции в память и переходит в режим x64.
option flat:1
.code
org 08000h
USE16

KERNEL_BUFFER equ 010000h
KERNEL_LBA    equ 65

stage2_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 07C00h
    sti

    mov [boot_drive], dl
    call serial_init
    mov al, '2'
    call serial_write
    mov eax, [kernel_sector_count]
    test eax, eax
    jz loader_error
    mov [sectors_remaining], eax

read_kernel:
    mov si, OFFSET disk_packet
    mov dl, [boot_drive]
    mov ah, 042h
    int 013h
    jc loader_error

    add word ptr [disk_packet_segment], 020h
    add dword ptr [disk_packet_lba], 1
    adc dword ptr [disk_packet_lba + 4], 0
    dec dword ptr [sectors_remaining]
    jnz read_kernel

    mov al, 'R'
    call serial_write
    cli
    in al, 092h
    or al, 2
    and al, 0FEh
    out 092h, al

    lgdt fword ptr [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    db 066h, 0EAh
    dd 08000h + (protected_entry - stage2_start)
    dw 08h

loader_error:
    mov si, OFFSET error_message
print_loop:
    lodsb
    test al, al
    jz loader_halt
    mov ah, 00Eh
    mov bx, 0004h
    int 010h
    jmp print_loop

loader_halt:
    cli
    hlt
    jmp loader_halt

serial_init:
    push ax
    push dx
    mov dx, 03F9h
    xor al, al
    out dx, al
    mov dx, 03FBh
    mov al, 080h
    out dx, al
    mov dx, 03F8h
    mov al, 1
    out dx, al
    mov dx, 03F9h
    xor al, al
    out dx, al
    mov dx, 03FBh
    mov al, 3
    out dx, al
    mov dx, 03FAh
    mov al, 0C7h
    out dx, al
    mov dx, 03FCh
    mov al, 0Bh
    out dx, al
    pop dx
    pop ax
    ret

serial_write:
    push bx
    push dx
    mov bl, al
serial_write_wait:
    mov dx, 03FDh
    in al, dx
    test al, 020h
    jz serial_write_wait
    mov dx, 03F8h
    mov al, bl
    out dx, al
    pop dx
    pop bx
    ret

USE32
protected_entry:
    mov ax, 010h
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 090000h
    cld
    mov dx, 03F8h
    mov al, 'P'
    out dx, al

    ; MSVC генерирует инструкции SSE2 в оптимизированном коде для x64.
    mov eax, cr0
    and eax, 0FFFFFFF3h
    or eax, 2
    mov cr0, eax
    mov eax, cr4
    or eax, 0600h
    mov cr4, eax

    mov esi, KERNEL_BUFFER
    cmp word ptr [esi], 05A4Dh
    jne protected_halt
    mov ebx, [esi + 03Ch]
    add ebx, esi
    cmp dword ptr [ebx], 00004550h
    jne protected_halt
    cmp word ptr [ebx + 018h], 020Bh
    jne protected_halt
    cmp dword ptr [ebx + 034h], 0
    jne protected_halt

    mov eax, [ebx + 030h]
    mov [kernel_image_base], eax
    mov edx, [ebx + 028h]
    add edx, eax
    mov [kernel_entry], edx

    movzx ecx, word ptr [ebx + 006h]
    movzx edx, word ptr [ebx + 014h]
    lea ebp, [ebx + edx + 018h]

map_sections:
    test ecx, ecx
    jz sections_mapped
    push ecx

    mov edi, [ebp + 00Ch]
    add edi, [kernel_image_base]
    mov ecx, [ebp + 008h]
    xor eax, eax
    rep stosb

    mov ecx, [ebp + 010h]
    test ecx, ecx
    jz section_done
    mov esi, [ebp + 014h]
    add esi, KERNEL_BUFFER
    mov edi, [ebp + 00Ch]
    add edi, [kernel_image_base]
    rep movsb

section_done:
    add ebp, 028h
    pop ecx
    dec ecx
    jmp map_sections

sections_mapped:
    mov dx, 03F8h
    mov al, 'M'
    out dx, al
    ; Выполнение прямого отображения (identity mapping) первого 1 ГиБ памяти с использованием страниц размером 2 МиБ.
    mov edi, 01000h
    xor eax, eax
    mov ecx, 03000h / 4
    rep stosd

    mov dword ptr [01000h], 02003h
    mov dword ptr [02000h], 03003h
    mov edi, 03000h
    mov eax, 00000083h
    mov ecx, 512
page_loop:
    mov [edi], eax
    mov dword ptr [edi + 4], 0
    add eax, 0200000h
    add edi, 8
    loop page_loop

    mov eax, cr4
    or eax, 020h
    mov cr4, eax
    mov eax, 01000h
    mov cr3, eax

    mov ecx, 0C0000080h
    rdmsr
    or eax, 0100h
    wrmsr

    mov eax, cr0
    or eax, 080000000h
    mov cr0, eax
    db 0EAh
    dd 08000h + (long_mode_entry - stage2_start)
    dw 018h

protected_halt:
    cli
    hlt
    jmp protected_halt

USE64
long_mode_entry:
    mov ax, 010h
    mov ds, ax
    mov es, ax
    mov ss, ax
    xor ax, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 090000h
    mov dx, 03F8h
    mov al, 'L'
    out dx, al
    mov eax, dword ptr [kernel_entry]
    jmp rax

USE16
boot_drive db 0
error_message db 'Stage2 disk error', 0
sectors_remaining dd 0
kernel_image_base dd 0
kernel_entry dd 0

; build-image.ps1 патчит двойное слово (dword), идущее сразу после этого маркера.
kernel_size_marker db 'KRNLSIZE'
kernel_sector_count dd 0

ALIGN 4
disk_packet:
    db 010h, 0
    dw 1
    dw 0
disk_packet_segment dw 01000h
disk_packet_lba dq KERNEL_LBA

ALIGN 8
gdt:
    dq 0000000000000000h
    dq 00CF9A000000FFFFh
    dq 00CF92000000FFFFh
    dq 00AF9A000000FFFFh
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt - 1
    dd 08000h + (gdt - stage2_start)

END stage2_start
