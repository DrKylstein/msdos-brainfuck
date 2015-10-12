DEBUG equ 0

ARGUMENT_LENGTH equ byte ptr es:[80h]
ARGUMENT_STRING equ 81h

MAX_PROGRAM_SIZE equ 16384
ARRAY_SIZE equ 32768

.model small
.stack
.data
    dseg:
        array db ARRAY_SIZE dup (0)
        bfCode db MAX_PROGRAM_SIZE dup (?)
        fileName db "FILENAME.TXT",0
        badFileMsg db "File not found.", 0Dh, 10h, "$"
        forbiddenMsg db "Access denied.", 0Dh, 10h, "$"
        badHandleMsg db "Bad handle.", 0Dh, 10h, "$"
        fileHandle dw 0
        bfPC dw 0
        arrayPointer dw 0
.code
    Print proc near
        mov   ah,09
        int   21h
        ret
    Print endp
    
    CloseFile proc near
        mov bx, fileHandle
        mov ah, 3Eh
        int 21h
        ret
    CloseFile endp
        
    Dispatch proc near
        ;mov ah, opCode
        cmp ah, '+'
        je Increment
        cmp ah, '-'
        je Decrement
        cmp ah, '>'
        je Advance
        cmp ah, '<'
        je Retreat
        cmp ah, '.'
        je Output
        cmp ah, ','
        je Read
        cmp ah, '['
        je BranchForward
        cmp ah, ']'
        je BranchBackward
        ret
        
    Output:
        mov bx, arrayPointer
        mov dl, array[bx]
        cmp dl, 0Ah
        je LineBreak
        mov ax, 0200h
        int 21h
        ret
    LineBreak:
        mov ax, 0200h
        mov dl, 0Dh
        int 21h        
        mov dl, 0Ah
        int 21h
        
    Increment:
        mov bx, arrayPointer
        inc array[bx]
        ret
    Decrement:
        mov bx, arrayPointer
        dec array[bx]
        ret
    Advance:
        inc arrayPointer
        ret
    Retreat:
        dec arrayPointer
        ret
        
    Read:
        mov ax, 0700h ;0800h is supposed to ctrl-c checking, but is same as 
                      ;0700h in DOSBox
        int 21h
        
        ;special inputs that are accpeted
        cmp al, 0Dh ;line end to be converted
        je LineInput 
        cmp al, 09h ;tab passed through
        je SymbolOk
        
        ;other non-character inputs rejected
        cmp al, ' '
        jb Return
        cmp al, '~'
        ja Return
    SymbolOk:
        mov bx, arrayPointer
        mov array[bx], al
        ret
    LineInput:
        mov al, 0Ah
        mov bx, arrayPointer
        mov array[bx], al
        ret

    BranchForward:
        mov bx, arrayPointer
        mov ah, array[bx]
        cmp ah, 0
        je Seek
        ret
        
    Seek:
        if DEBUG
        lea dx, skipMsg
        call Print
        endif
        
        mov cx, 1
        mov bx, bfPC
    SeekLoop:
        inc bx
        mov ah, bfCode[bx]
        cmp ah, '['
        je Nested
        cmp ah, ']'
        je Closing
        jmp SeekLoop
    Nested:
        inc cx
        jmp SeekLoop
    Closing:
        dec cx
        jnz SeekLoop
        mov bfPC, bx
        
    BranchBackward:
        mov bx, arrayPointer
        mov ah, array[bx]
        cmp ah, 0
        jne SeekBack
        ret
    SeekBack:
        if DEBUG
        lea dx, returnMsg
        call Print
        endif
        mov cx, 1
        mov bx, bfPC
    SeekBackLoop:
        dec bx
        mov ah, bfCode[bx]
        cmp ah, ']'
        je BackNested
        cmp ah, '['
        je Opening
        jmp SeekBackLoop
    BackNested:
        inc cx
        jmp SeekBackLoop
    Opening:
        dec cx
        jnz SeekBackLoop
        mov bfPC, bx
        
        
    Return: 
        ret
    Dispatch endp

    main proc
        ;point es to dseg, leave ds at PSP
        mov ax, seg dseg
        mov es, ax
        
        mov si, ARGUMENT_STRING
        lea di, fileName
        
    SkipSpaces:
        lodsb
        cmp al, ' '
        je SkipSpaces
        
        dec si
    GetFileName:
        lodsb
        cmp al, 0Dh
        je GotFileName
        cmp al, ' '
        je GotFileName
        stosb
        jmp GetFileName
    
    GotFileName:
        ;terminate string
        mov byte ptr es:[di], 0
        ;point ds to dseg
        mov ax, es
        mov ds, ax
    
        ;open file
        mov ah, 3Dh
        mov al, 0
        lea dx, fileName
        int 21h
        jnc FileGood
        
        ;bad file
        lea dx,badFileMsg
        call Print
        jmp Exit

    FileGood:
        mov fileHandle, ax
        
    ReadFile:
        mov ax, 3F00h
        lea dx, bfCode
        mov cx, MAX_PROGRAM_SIZE-1
        mov bx, fileHandle
        int 21h
        jc ReadError
        call CloseFile
        mov bx, ax
        mov byte ptr bfCode[bx], 0
    Run:
        if DEBUG
        mov bx, bfPC
        mov dl, bfCode[bx]    
        mov ax, 0200h
        int 21h
        endif
        
        mov bx, bfPC
        mov ah, bfCode[bx]
        
        ; exit at end of file
        cmp ah, 0
        je Done
        
        call Dispatch
        inc bfPC
        jmp Run
    
    ReadError:
        cmp ax, 5
        jne BadHandle
        lea dx,forbiddenMsg
        jmp PrintError
    BadHandle:
        lea dx,badHandleMsg
    PrintError:
        call Print
        call CloseFile
        jmp Exit
        
    Done:
    Exit:
        mov ax ,4c00h
        int 21h
    main endp
end main