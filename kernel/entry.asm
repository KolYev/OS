option casemap:none

EXTERN KernelMain:PROC
PUBLIC KernelEntry
PUBLIC SerialInit
PUBLIC SerialWriteByte

.code

KernelEntry PROC
    cli
    lea rsp, KernelStackTop
    and rsp, -16
    sub rsp, 20h
    call KernelMain

kernel_halt:
    hlt
    jmp kernel_halt
KernelEntry ENDP

SerialInit PROC
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
    ret
SerialInit ENDP

SerialWriteByte PROC
    mov r8b, cl
serial_wait:
    mov dx, 03FDh
    in al, dx
    test al, 020h
    jz serial_wait
    mov dx, 03F8h
    mov al, r8b
    out dx, al
    ret
SerialWriteByte ENDP

.data?
ALIGN 16
KernelStack BYTE 16384 DUP (?)
KernelStackTop LABEL BYTE

END
