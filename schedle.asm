.186
;----------------------------------------------------------------------------------------------
data segment
	p_proc_read dw PCB0  	;当前运行的进程的PCB的地址
	PCB0 dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0
	PCB1 dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 1,0, 0
	;       es ds di si bp sp bx dx cx ax ip cs flag ss id name     pro_flag
        ;	0  2  4  6  8  10 12 14 16 18 20 22 24   26  28  30       32
	PCB_SIZE dw 34 ;在enum8086中，PCB0与PCB1之间有4个字节空洞，则size为38，但是在dosbox中没有
	PCB_AFTER dw 0
data ends

;----------------------------------------------------------------------------------------------
stack_first segment
	db 400 dup(0)
stack_first ends

;----------------------------------------------------------------------------------------------
stack_second segment
	db 400 dup(0)
stack_second ends

;----------------------------------------------------------------------------------------------
code segment
	assume cs:code, ds:data, ss:stack_first
;----------------------------------------------------------------------------------------------
start:
	mov ax, data
	mov ds, ax
	mov ax, stack_first
	mov ss, ax
	mov sp, 400
	
	mov ax, data
	mov PCB0[0], ax
	mov PCB0[2], ax
	mov ax, seg first
	mov PCB0[22], ax
	mov bx, offset first
	mov PCB0[20], bx
	mov PCB0[26], ss
	mov PCB0[10], sp

	mov ax, data
	mov PCB1[0], ax 		;设置es
	mov PCB1[2], ax 		;设置ds为数据段的基地址
	mov ax, seg second
	mov PCB1[22], ax 		;设置cs
	mov bx, offset second
	mov PCB1[20], bx 		;设置ip
	mov ax, stack_second
	mov PCB1[26], ax 		;设置ss
	mov PCB1[10], 400 		;设置sp
	
	mov PCB0[32], 1 	
	mov PCB1[32], 1

	push ds
	xor ax, ax
	mov ds, ax
	mov ax, offset timer
	mov ds:[180h], ax 		;使用了int 60h的中断,使用的软中断实现的调度
	mov ax, seg timer 
	mov ds:[180h+2], ax
	pop ds  
	mov ax, p_proc_read
	add ax, PCB_SIZE
 	mov PCB_AFTER, ax 		;设置进程PCB地址的最大值，大于这个最大值则从头开始执行
    
	call first
;----------------------------------------------------------------------------------------------


;----------------------------------------------------------------------------------------------

;中断处理函数
timer proc near
	pusha
	push ds
	push es
	xor ax, ax
	mov bx, p_proc_read
	mov di, bx
	mov ax, ds
	mov es, ax
	
	mov ax, ss
	mov ds, ax
	mov si, sp
	mov cx, 13 		;将被中断进程的栈中的所有寄存器赋值给对应的PCB块
	cld
	rep movsw
	mov ax, data 		;上面改变了ds，则需要重新赋值，否则会出现错误，因为寻址是段地址+偏移地址，段地址错误，后果不堪设想
	mov ds, ax
	
	mov [di], ss 		;将ss赋值给PCB块，其实这句可以省略的，只要PCB块中ss被初始化了，则不会改变了
	sub di, 16
	mov ax, 6 		;将PCB中sp+6,因为压入了flags，cs，ip，回到被中断时进程的sp
	add [di], ax
	
    	mov ax, PCB_SIZE
	add p_proc_read, ax 	
	mov ax, p_proc_read
	cmp ax, PCB_AFTER 	;执行下一个进程，重新给p_proc_read赋值，指向下一个被运行的进程的PCB	
	jg next_process 	;判断当前是否执行到最后一个进程
	jmp set_next_process

next_process:
	lea ax, PCB0
    	mov p_proc_read, ax
	jmp set_next_process

set_next_process:
	mov si, p_proc_read
    	mov ss, [si+26] 	;转换栈，将将要执行进程PCB块中的ss和sp赋值给ss和sp
    	mov sp, [si+10]  
    	sub sp, 26   		;使用了movsw，则需要在栈中开辟26个字节，将PCB中的所有寄存器赋值到栈中，与下面的pop对应，否则栈会不平衡
    	mov di, sp
    	mov ax, ss
    	mov es, ax    
    	mov cx, 13
    	cld
    	rep movsw 		;将PCB块中的所有寄存器复制到栈中
	xor ax, ax
	mov al, 20h 		;说明中断结束
	out 20h, al
	out 0a0h, al
	pop es 			;将所有的寄存器出栈，然后开始执行
	pop ds
	popa
	iret
timer endp
;----------------------------------------------------------------------------------------------

;----------------------------------------------------------------------------------------------
second proc near

s:
	mov ah, 0eh
	mov al, 'a'
	int 10h 
	int 60h
    jmp s
second endp
;----------------------------------------------------------------------------------------------


;----------------------------------------------------------------------------------------------
first  proc near

sq:
	mov ah, 0eh
	mov al, 'b'
	int 10h  
	int 60h
	jmp sq
first endp
;----------------------------------------------------------------------------------------------
code ends
end start
