.model compact 

.data

    ;File IO variables
    filename db "test.txt" , 0 
    MAX_FILE_SIZE equ 30000  ;30k                                                            
    BUFFER  db 2048 dup (?), "$" 
    FILE_SIZE dw ?
    IO_HANDLE dw ?
    org_xmax db 78d
    org_xmin db 1d
    org_ymax db 24d
    org_ymin db 1d
    ERROR_MSG_1 db "Error occured! Failed to open!$"
    ERROR_MSG_2 db "Error occured! Failed to read!$" 
    
    ;Scroll and cursor variable
    ;MAX_PAGE 
    ;MIN_PAGE 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;               Main                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.code 
    org 100h

MAIN        PROC
    
    mov ax, @data
	mov ds, ax

    mov ah, 00h
    mov al, 03h ;mode 
    int 10h

    mov ax, 0B800H
	mov es, ax


    call CLRSCR
    call commands

MAIN        ENDP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;         Reserve Commands          ;
;   Ctrl + O  (Open file)           ;
;   Ctrl + s  (Save file)           ;
;   Ctrl + c  (Copy)                ;
;   Ctrl + v  (Paste)               ;
;   arrows    (move cursor)         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
commands                PROC

             
            waitforpress:
                        ;BIOS irs
                        mov ah, 0h
						int 16h
                        ;arrow buttons are used for navigation
                        cmp ah, 48h 
                        je up
                        cmp ah, 4bh
                        je left 
                        cmp ah, 4dh
                        je right 
                        cmp ah, 50h 
                        je down 
                        cmp ah, 1h 
                        je escape 
                        ;special input ctrl + O to open file 
                        cmp ax, 180fh 
                        je openFile 
                        ;if detected letters
                        jmp waitforpress

            escape:     
                        
                        call exit
            up:         
                        ;move cursor up
                        sub dh, 1
                        cmp dh, org_ymin
                        jl reached_ytop
                        call  SETXY
                        jmp waitforpress
            left:       
                        ;move cursor left 
                        sub dl, 1
                        ;check if reached max left 
                        cmp dl, org_xmin
                        jl left_scroll
                        ;cmp dl, 0
                        ;jl left_scroll
                        call  SETXY
                        jmp waitforpress
            right:      
                        ;move cursor right
                        add dl, 1
                        cmp dl, org_xmax
                        jg right_scroll
                        ;cmp dl, 80 
                        ;jg right_scroll
                        call  SETXY
                        jmp waitforpress
            down:       
                        ;move cursor down
                        add dh, 1
                        cmp dh, org_ymax
                        jg reached_ybot
                        call  SETXY
                        jmp waitforpress 
            reached_ytop:
                        mov dh, org_ymin
                        call SETXY
                        jmp waitforpress
            reached_ybot:
                        mov dh, org_ymax
                        call SETXY
                        jmp waitforpress
            openFile: 
                        call FileIO
                        jmp waitforpress
            right_scroll:
                        ;make sure that word wrap wont occur here
                        add di, 1
                        cmp di, FILE_SIZE
                        je normalize_di_upp
                        call DisplayContent
                        ;mov dh, 0 
                        ;mov dl, 0 
                        ;call SETXY
                        ;mov dl, org_xmax
                        ;call SETXY
                        jmp waitforpress 
            left_scroll:
                        ;make sure that word wrap wont occur her
                        sub di, 1
                        cmp di, 0
                        jl normalize_di
                        call DisplayContent
                        ;mov dh, 0 
                        ;mov dl, 0 
                        ;call SETXY
                        mov dl , org_xmin
                        call SETXY
                        jmp waitforpress 
            normalize_di: 
                        xor di, di 
                        call DisplayContent
                        mov dl , org_xmin
                        call SETXY
                        jmp waitforpress   
            normalize_di_upp:

            
            
        

commands                ENDP

showCurs                PROC
            ;show standard cursor
            standard: 
                        mov ch, 6
                        mov cl, 7
                        mov ah, 1 
                        int 10h
            ;show INSERT cursor 

                        ret
showCurs                ENDP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;           Import File             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FileIO      PROC

                mov dx, offset filename 
                mov al, 00h     ;Read mode
                mov ah, 3dh     ;Open a file
                int 21h         ;call dos service

                mov IO_HANDLE, ax    ;check if file is successfully opened
                jnc IO_success 
                jmp IO_errorOccured_1

        ;read if file open successfully
        IO_success: 
                ;xor dx, dx 
                mov ah, 3fh
                mov bx, IO_HANDLE
                mov cx, MAX_FILE_SIZE   ;number of maximum bytes allowed
                mov dx, offset BUFFER
                int 21h 
                
                ;ax == # byte read
                mov si, offset FILE_SIZE
                mov [si], ax
                
                jnc IO_empty
                jmp IO_exit

        IO_empty: 
                cmp ax, 0               ;check if file is empty
                je IO_display

        ;close file and display content
        IO_display:
                ;close file 
                ;mov ah, 3eh
                ;mov bx, IO_HANDLE
                ;int 21h 
                push di
                xor di, di ;read from 0
                call DisplayContent
                pop di 

                ;reset cursor 
                mov dl, org_xmin
                mov dh, org_ymin
                call SETXY

                jmp IO_exit
                  
        ;level 1 error 
        IO_errorOccured_1:
                ;display an error message 
                mov dx, offset IO_errorOccured_1
                mov ah, 09h 
                int 21h 
                mov ax, 4c01h ;end program with level 1 error 
                int 21h
        
        IO_errorOccured_2:
                ;display an error message 
                mov dx, offset IO_errorOccured_2
                mov ah, 09h 
                int 21h 
                mov ax, 4c02h ;end program with level 1 error 
                int 21h
        IO_exit:
                ;clear si 
                ret

FileIO      ENDP

DisplayContent      PROC
                    push bx
                    ;push dx
                    mov dl, 1
                    mov dh, 1
                    call SETXY
                    lea bx, [buffer + di]
                    mov cx, FILE_SIZE ;maximum to show per page
                    mov si, di
            main_disp: 
                   
                    mov al, [bx]
                    ;check for new line
                    cmp al, 0DH
                    je Carriage_ret
                     
                    ;je NewLine
                    ;check for blank space
                    ;check for eof
                    ;check for max_row
                    cmp dl, org_xmax
                    jg update_pos
                    ;else print
                    jmp print_func
                    ;if all cx are iterated, then end this method
            Carriage_ret: 
                    add bx, di
                    inc dh
                    mov dl, 1
                    call SETXY
                    ;print content after newline
                    add bx, 2  ;update 2 CR bytes
                    sub cx, 2
                    ;update cursor
                    
                    jnz main_disp 
                    jmp end_print 
                    
                    
            print_func: 
                    push cx
                    mov ah, 0Ah
                    mov bh, 0
                    mov cx, 1
                    int 10h 
                    pop cx
                    inc dl 
                    call SETXY
                    jmp update_pos 
            reached_max: 
                    ;if AL in BX == NULL 
                    ;add line, else stay on the same line
                    cmp al, 00h 
                    je mov_next
            mov_next: 
                    inc dh
                    mov dl, 1
                    call SETXY
                    jmp main_disp
            update_pos:
                    inc bx 
                    dec cx
                    jnz main_disp 
                    jmp end_print 
            end_print: 
                    pop bx
                    ;pop dx
                    ret


            
DisplayContent      ENDP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;         Create new File           ; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;            Overwrite              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;      File navigation(Scroll)      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;      Insert(overtype), Delete     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;       Overwriting the File        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;             Cut/paste             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;         save file (close)         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CLRSCR				PROC
					    push ax
                        push bx
					    push cx
					    push dx
					    mov ax, 0600H
					    mov cx, 0
					    mov dx, 184FH
					    mov bh, 7
					    int 10H
					    mov ah, 2
					    mov bh, 0
					    mov dx, 0
					    int 10H
					    pop dx
				    	pop cx
				    	pop bx
					    pop ax
					    ret 
CLRSCR				ENDP


;exit

exit    PROC
    mov ah, 4ch 
    int 21h 
    ret 
exit    ENDP

SETXY               PROC
                        mov ah, 02
                        mov bh, 0
                        int 10h
                        ret
SETXY               ENDP 

end MAIN
