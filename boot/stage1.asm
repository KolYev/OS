; Загрузочный сектор BIOS. Загружает область stage2 фиксированного размера по адресу 0000:8000.
option flat:1
.code
org 07C00h
USE16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 07C00h
    sti

    mov [boot_drive], dl

    ; Требует расширения INT 13h (EDD).
    mov bx, 055AAh
    mov ah, 041h
    int 013h
    jc disk_error
    cmp bx, 0AA55h
    jne disk_error
    test cx, 1
    jz disk_error

    mov si, OFFSET disk_packet
    mov dl, [boot_drive]
    mov ah, 042h
    int 013h
    jc disk_error

    mov dl, [boot_drive]
    push 0000h
    push 08000h
    retf

disk_error:
    mov si, OFFSET error_message
print_loop:
    lodsb
    test al, al
    jz halt
    mov ah, 00Eh
    mov bx, 0007h
    int 010h
    jmp print_loop

halt:
    cli
    hlt
    jmp halt

boot_drive db 0
error_message db 'Boot disk read error', 0

ALIGN 4
disk_packet:
    db 010h, 0
    dw 64
    dw 08000h, 0000h
    dq 1

db 510 - ($ - start) dup (0)
dw 0AA55h

END start
