;*******************************************************************************
;
; ƴͼ��Ϸ
;
;
;*******************************************************************************
.386
.model flat, stdcall
option casemap : none

include windows.inc
include kernel32.inc
include user32.inc
include gdi32.inc
include comctl32.inc
include winmm.inc

includelib kernel32.lib
includelib user32.lib
includelib gdi32.lib
includelib comctl32.lib
includelib winmm.lib


;*******************************************************************************
; �궨��
;*******************************************************************************

;
; ͼ�� / ���
;
IDI_APP     equ 1000h
IDC_NORMAL  equ 1001h
IDC_FINGER  equ 1002h

;
; �˵� / ������ / ���ڶԻ���
;
IDM_APP             equ 2000h
IDM_PREV_PICTURE    equ 2001h
IDM_NEXT_PICTURE    equ 2002h
IDM_RESTART_PICTURE equ 2003h
IDM_ABOUT           equ 2004h
IDM_EXIT            equ 2005h

IDB_TOOLBAR equ 3000h

IDD_ABOUT   equ 4000h


;*******************************************************************************
; ���ݶ�
;*******************************************************************************

;
; ������ / ��������ť
;
.const
AppName db  "ƴͼ��Ϸ", 0

TBButtonNum dd 6h
TBButton equ this byte
TBBUTTON < 0, IDM_PREV_PICTURE, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0, -1 >
TBBUTTON < 1, IDM_NEXT_PICTURE, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0, -1 >
TBBUTTON < 2, IDM_RESTART_PICTURE, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0, -1 >
TBBUTTON < 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0, -1 >
TBBUTTON < 3, IDM_ABOUT, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0, -1 >
TBBUTTON < 4, IDM_EXIT, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0, -1 >

;
; ����ʵ������������в��� / �����ڴ�С����񡢾�����ࡢ��Ϣ������
;
.data?
AppInstance HINSTANCE ?
AppCmdLine  LPSTR ?

MainWndRect     RECT <>
MainWndWidth    dd ?
MainWndHeight   dd ?
MainWndStyle    dd ?
MainWndHdl      HWND ?
MainWndCls      WNDCLASSEX <>
MainWndMsg      MSG <>
MainWndPosX     dd ?
MainWndPosY     dd ?

;
; ��Ϸ����
;
.const
TotalPicture    dd  40  ; ��ͼƬ����

ClientRect  RECT    < 0, 0, 617, 210 >  ; �ͻ�����С
GameOrgX    dd      6                   ; ��Ϸ����������ϵԭ�� x ����
GameOrgY    dd      33                  ; ��Ϸ����������ϵԭ�� y ����
StatOrgX    dd      313                 ; ״̬����������ϵԭ�� x ����
StatOrgY    dd      30                  ; ״̬����������ϵԭ�� y ����

StrMessageBoxInfo   db  "��ʾ��Ϣ", 0
StrMessageBoxError  db  "���ش���", 0
StrRestartPicture   db  "ȷ�����¿�ʼ��?", 0
StrFinishPicture    db  "ƴͼ���!", 0

StrPictureName      db  "Data\Picture_%d.bmp", 0    ; ��Ϸԭͼ�ļ�����ʽ
StrPictureError     db  "����ͼƬ��Դ %s ʧ��!", 0
StrHdcError         db  "�����豸�������ʧ��!", 0

StrRestartSound     db "Data\Restart.wav", 0
StrStepSound        db "Data\Step.m4a" , 0
StrUsedTime         db  "UsedTime: %03d sec", 0
StrUsedStep         db  "UsedSteps: %03d steps", 0
StrIsFinish         db  "��ϲ��, ƴͼ���.������ս��һ�ذɣ����꣡", 0
StrAuthor           db  "# 07712001 Basic Version 2.0 #", 0

FontName    db  "����", 0   ; ��������

TimerId     dd  1200 ;

.data?
CurPicture  dd      ?           ; ��ǰͼƬ
CurBlocks   db      18 dup(?)   ; ��ǰ��Ϸ�������������ͼ�������� 3 �� * 6 ��
UsedTime    dd      ?           ; ��ǰͼƬ����ʱ��, ��λ : ��
UsedStep    dd      ?           ; ��ǰͼƬ���߲���
IsFinish    dd      ?           ; ��ǰͼƬ�Ƿ��Ѿ����

PictureDc   HDC     ?   ; ��Ϸԭͼ�豸����
PictureBM   HBITMAP ?   ; ��Ϸԭͼλͼ���
BackClr     dd      ?   ; ���屳����ɫ
FrameClr    dd      ?   ; ͼƬ�߿���ɫ
LightClr    dd      ?   ; �߹�ʴ���ɫ
ShadowClr   dd      ?   ; ��Ӱ�ʴ���ɫ

FontHdl     HFONT   ?   ; ����
FontFtClr   dd      ?   ; ����ǰ��ɫ
FontBkClr   dd      ?   ; ���屳��ɫ

NormalCursor    HCURSOR ?   ; ��ͨ���
FingerCursor    HCURSOR ?   ; ��ָ���


;*******************************************************************************
; �����
;*******************************************************************************
.code

;-------------------------------------------------------------------------------
; �� [ min, max ] ����������һ�������
; RandSeed = ( RandSeed * 23 + 7 ) % ( max - min + 1 )
;-------------------------------------------------------------------------------
RandomNumber proc min:DWORD, max:DWORD
    invoke GetTickCount
    mov ecx, 23
    mul ecx
    add eax, 7
    mov ecx, max
    sub ecx, min
    inc ecx
    xor edx, edx
    div ecx
    add edx, min
    mov eax, edx
    ret
RandomNumber endp

;-------------------------------------------------------------------------------
; �Ե� CurPicture ��ͼƬ��ʼһ����Ϸ
;-------------------------------------------------------------------------------
StartPicture proc uses ebx edi, isNewPicture:BOOL
    local filename[256] : byte
    local filerror[256] : byte
    local blockTmp[18] : byte
    local blockCnt : byte

    ;
    ; �õ�����λͼͼƬ�ľ��
    ;
    .if PictureBM
        invoke DeleteObject, PictureBM
    .endif

    invoke wsprintf, addr filename, offset StrPictureName, CurPicture
    invoke LoadImage, NULL, addr filename, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE
    
    .if ( !eax )
        invoke wsprintf, addr filerror, offset StrPictureError, addr filename
        invoke MessageBox, MainWndHdl, addr filerror, offset StrMessageBoxError,
               MB_OK or MB_ICONSTOP or MB_APPLMODAL
        invoke ExitProcess, 0
    .endif
    
    mov PictureBM, eax
    invoke SelectObject, PictureDc, PictureBM
    
    ;
    ; ����ؽ�ԭͼ��ɢ�� 3 �� 6 �� �� 18 ��, ����ɢ��ı�Ŵ浽 CurBlocks ������
    ;
    ; �����ɢ�ķ���Ϊ :
    ;   0����ʼ״̬ N = 17, M = 0, r = ?
    ;   1����ԭͼ�͵ػ��ֳ� N ����ͼ, ˳����Ϊ 0 �� N, ���俴��һ���Զ���
    ;   2���� [0,N] ����������һ����� r, ����ͼ�����е� r ��ȡ��
    ;   3������� r �浽 CurBlocks ����� M �ŵ�Ԫ
    ;   4��N = N -1, M = M + 1, �ص��� 1 ��
    ;
    xor ecx, ecx
    .while ecx < 17
        mov blockTmp[ ecx ], 1
        inc ecx
    .endw
    
    mov blockCnt, 17
    mov ebx, offset CurBlocks
    .while blockCnt > 0
        xor eax, eax
        mov al, blockCnt
        dec eax
        mov edi, eax
        invoke RandomNumber, 0, eax                                                    
        xor ecx, ecx
        xor edx, edx
        .while ecx < 17
            .if blockTmp[ ecx ] == 1                
                .if edx == eax
                    mov blockTmp[ ecx ], 0
                    mov [ebx][edi], cl
                    dec blockCnt
                    .break
                .endif
                inc edx    
            .endif
            inc ecx
        .endw
    .endw
    
    ; ��Ϸ������һ��������Ϊ��, Ϊ��ͼ�ƶ��ڳ���λ
    mov al, -1
    mov [ebx][17], al
    
    mov UsedTime, 0
    mov UsedStep, 0
    mov IsFinish, FALSE        
        
    ; ��ʹ��Ϸ�ػ�
    invoke InvalidateRect, MainWndHdl, NULL, FALSE
    
    ; ������ͼ��������
    .if isNewPicture == FALSE
        invoke PlaySound, offset StrRestartSound, AppInstance, SND_FILENAME or SND_ASYNC
    .endif
    
    ret
StartPicture endp

;-------------------------------------------------------------------------------
; ����һ֡��Ϸ
;-------------------------------------------------------------------------------
DrawGame proc uses ebx esi, hdc:HDC
    local oldPen:HPEN
    local oldBrush:HBRUSH
    local oldBkMode:DWORD
    local rect:RECT
    local dstRow:byte
    local dstCol:byte
    local srcRow:byte
    local srcCol:byte
    local dstX:DWORD
    local dstY:DWORD
    local srcX:DWORD
    local srcY:DWORD
    local strX:DWORD
    local strY:DWORD
    local strUsedTime[32]:byte
    local strUsedStep[32]:byte    

    ;
    ; ѡ��ʴ� / ��ˢ���豸����
    ;
    invoke GetStockObject, WHITE_PEN
    invoke SelectObject, hdc, eax
    mov oldPen, eax    
    invoke GetStockObject, WHITE_BRUSH
    invoke SelectObject, hdc, eax
    mov oldBrush, eax
    
	;
    ; ������Ϸ�������°�Ч��
    ;
    mov eax, GameOrgX
    mov ecx, GameOrgY
    mov rect.left, eax
    sub rect.left, 3
    mov rect.top, ecx
    sub rect.top, 3
    mov rect.right, eax
    add rect.right, 303
    mov rect.bottom, ecx
    add rect.bottom, 152
    
    ; ������Ӱ�ʴ���ɫ             
    invoke SetDCPenColor, hdc, ShadowClr    

    ; ������� / �ϱ�
    invoke MoveToEx, hdc, rect.left, rect.bottom, NULL            
    invoke LineTo, hdc, rect.left, rect.top            
    invoke LineTo, hdc, rect.right, rect.top
    
    ; ���ø߹�ʴ���ɫ
    invoke SetDCPenColor, hdc, LightClr
    
    ; �����ұ� / �±�
    invoke LineTo, hdc, rect.right, rect.bottom    
    sub rect.left, 1
    invoke LineTo, hdc, rect.left, rect.bottom
            
    ;
    ; ˳�������Ϸ����������, ���ƴ�ɢ����ͼ��������Ч��( ���ϸ߹�����Ӱ )
    ;
    mov ebx, offset CurBlocks
    xor esi, esi
    xor eax, eax
    mov ecx, 6
    .while esi < 18          
        ;
        ; ���㵱ǰ������Ŀ���豸����(��Ϸ�����)�ϵ�����:
        ;   dstRow = ���� / 6, dstCol = ���� % 6
        ;   dstX = GameOrgX + dstCol * 50
        ;   dstY = GameOrgY + dstRow * 50
        ;
        mov eax, esi
        div cl
        mov dstRow, al
        mov dstCol, ah 
			       
        xor eax, eax
        mov eax, 50
        mul dstCol
        add eax, GameOrgX
        mov dstX, eax
        
        xor eax, eax
        mov eax, 50
        mul dstRow
        add eax, GameOrgY
        mov dstY, eax
        
        ;
        ; ���㵱ǰ���������õ���ͼ�ں�̨�豸����(��Ϸԭͼ)�ϵ�����
        ; ���������������ͼʱ, ���Ϊ����ͼ��ԭͼ�е����
        ; ��������δ������ͼʱ, ���Ϊ -1
        ;
        ;   srcRow = ��� / 6, srcCol = ��� % 6
        ;   srcX = 0 + srcCol * 50
        ;   srcY = 0 + srcRow * 50
        ;
        ; �Ĵ���ʹ��Լ��:
        ;   eax, ecx, edx Ϊ�����߼Ĵ���, �ɵ����߱���
        ;   ebx, esi, edi Ϊ�������߼Ĵ���, �ɱ������߱���
        ;
        push ecx
        xor eax, eax
        mov al, [ebx][esi]
        
        ; �����ǰ�����������ͼ
        .if al != -1          
            div cl
            mov srcRow, al
            mov srcCol, ah
            
            xor eax, eax
            mov eax, 50
            mul srcCol
            mov srcX, eax
            
            xor eax, eax
            mov eax, 50
            mul srcRow
            mov srcY, eax

            ; ����ͼ��ԭͼ��������ǰ����
            invoke BitBlt, hdc, dstX, dstY, 50, 50, PictureDc, srcX, srcY, SRCCOPY
            
            ;
            ; �������ϸ߹�����Ӱ
            ;
            mov eax, dstX
            mov ecx, dstY
            mov rect.left, eax
            mov rect.top, ecx
            mov rect.right, eax
            add rect.right, 49
            mov rect.bottom, ecx
            add rect.bottom, 49
            
            ; ���ø߹�ʴ���ɫ          
            invoke SetDCPenColor, hdc, LightClr    

            ; ������� / �ϱ�
            invoke MoveToEx, hdc, rect.left, rect.bottom, NULL            
            invoke LineTo, hdc, rect.left, rect.top            
            invoke LineTo, hdc, rect.right, rect.top
            
            ; ������Ӱ�ʴ���ɫ
            invoke SetDCPenColor, hdc, ShadowClr
            
            ; �����ұ� / �±�
            invoke LineTo, hdc, rect.right, rect.bottom    
            sub rect.left, 1
            invoke LineTo, hdc, rect.left, rect.bottom
        
        ; �����ǰ����δ������ͼ
        .else
            mov eax, dstX
            mov ecx, dstY
            mov rect.left, eax
            mov rect.top, ecx
            mov rect.right, eax
            add rect.right, 50
            mov rect.bottom, ecx
            add rect.bottom, 50            
            
            ; ���ô��屳���ʴ� / ��ˢ��ɫ
            invoke SetDCPenColor, hdc, BackClr
            invoke SetDCBrushColor, hdc, BackClr
    
            ; ��������Ϊ���屳����ɫ
            invoke Rectangle, hdc, rect.left, rect.top, rect.right, rect.bottom
        .endif
        
        pop ecx
        inc esi
    .endw   
    
    ;
    ; ����ԭͼ���߿�, �������Ϊԭͼ��һ���С
    ;
    invoke StretchBlt, hdc, StatOrgX, StatOrgY, 300, 150,
           PictureDc, 0, 0, 300, 150, SRCCOPY   
    
    mov eax, StatOrgX
    mov ecx, StatOrgY
    mov rect.left, eax
    mov rect.top, ecx
    mov rect.right, eax
    add rect.right, 299
    mov rect.bottom, ecx
    add rect.bottom, 149
            
    ; ���ñ߿�ʴ���ɫ
    invoke SetDCPenColor, hdc, FrameClr

    ; ���Ʊ߿�
    invoke MoveToEx, hdc, rect.left, rect.bottom, NULL            
    invoke LineTo, hdc, rect.left, rect.top            
    invoke LineTo, hdc, rect.right, rect.top
    invoke LineTo, hdc, rect.right, rect.bottom
    invoke LineTo, hdc, rect.left, rect.bottom


    ;
    ; ���ƹ���������Ч��
    ;
    mov eax, GameOrgX
    mov ecx, GameOrgY
    add eax, 0
    add ecx, 25
    mov rect.left, eax
    mov rect.top, ecx
    mov rect.right, eax
    add rect.right, 605
    mov rect.bottom, ecx
    add rect.bottom, 25
    
    ;
    ; ��������ʱ�� / ���߲�����������ӰЧ��
    ;
    mov eax, GameOrgX
    mov ecx, GameOrgY
    add eax, 0
    add ecx, 155
    mov rect.left, eax
    mov rect.top, ecx
    mov rect.right, eax
    add rect.right, 605
    mov rect.bottom, ecx
    add rect.bottom, 25
    
    ; ���ô��屳���ʴ� / ��ˢ��ɫ
    invoke SetDCPenColor, hdc, BackClr
    invoke SetDCBrushColor, hdc, BackClr  
    
    ; ��������Ϊ���屳����ɫ, ��������һ֡�����򴦲�������
    invoke Rectangle, hdc, rect.left, rect.top, rect.right, rect.bottom
            
    mov eax, GameOrgX
    mov ecx, GameOrgY
    mov strX, eax
    mov strY, ecx
    
    ; �������� / ����ģʽ
    invoke SelectObject, hdc, FontHdl    
    invoke SetBkMode, hdc, TRANSPARENT
    mov oldBkMode, eax
    
    ; ��������ʱ��
    add strX, 0
    add strY, 158
    invoke wsprintf, addr strUsedTime, offset StrUsedTime, UsedTime
    invoke SetTextColor, hdc, FontBkClr
    invoke TextOut, hdc, strX, strY, addr strUsedTime, 20
    add strY, 2
    invoke SetTextColor, hdc, FontFtClr
    invoke TextOut, hdc, strX, strY, addr strUsedTime, 20
    
    ; �������߲���
    add strX, 200
    invoke wsprintf, addr strUsedStep, offset StrUsedStep, UsedStep
    invoke SetTextColor, hdc, FontBkClr
    invoke TextOut, hdc, strX, strY, addr strUsedStep, 20
    
    invoke SetTextColor, hdc, FontFtClr
    invoke TextOut, hdc, strX, strY, addr strUsedStep, 20
    
    ; ������Ϸ�汾
    add strX, 200
    
    invoke SetTextColor, hdc, FontBkClr
    invoke TextOut, hdc, strX, strY, offset StrAuthor, 30
    
    invoke SetTextColor, hdc, FontFtClr
    invoke TextOut, hdc, strX, strY, offset StrAuthor, 30      
    
    invoke SetBkMode, hdc, oldBkMode
    invoke SelectObject, hdc, oldBrush
    invoke SelectObject, hdc, oldPen
    
    ret
DrawGame endp

;-------------------------------------------------------------------------------
; ���������ָ���������ż�����������ͼ��������µ�����������
;-------------------------------------------------------------------------------
TranMousePos proc uses ebx, posX:DWORD, posY:DWORD, pOldId:DWORD, pNewId:DWORD
    local edgeRect:RECT
    local row:byte
    local col:byte
    
    ; ��ʼ��ԭ / ������Ϊ -1
    mov ebx, pOldId
    mov byte ptr [ebx], -1
    mov ebx, pNewId
    mov byte ptr [ebx], -1
        
    ; ����������Ϸ���߽緶Χ
    mov eax, GameOrgX
    mov edgeRect.left, eax
    add eax, 300
    mov edgeRect.right, eax
    mov eax, GameOrgY
    mov edgeRect.top, eax
    add eax, 150
    mov edgeRect.bottom, eax

    ; ���������Ϸ���߽緶Χ��ֱ�ӷ���, [ 0, edgeRect.right ), [ 0, edgeRect.bottom )
    mov eax, posX
    mov ecx, posY
    .if ( eax < edgeRect.left || eax >= edgeRect.right \
          || ecx < edgeRect.top || ecx >= edgeRect.bottom )        
        ret
    .endif
    
    ;
    ; ���������ָ���������кż�������
    ;
    ;   row = ( posY - edgeRect.top ) / 40
    ;   col = ( posX - edgeRect.left ) / 40 
    ;   ���� = row * 7 + col
    ;
    mov ecx, 50
    
    mov eax, posY
    sub eax, edgeRect.top
    div cl
    mov row, al
    
    mov eax, posX
    sub eax, edgeRect.left
    div cl
    mov col, al
    
    mov ecx, 6
    xor eax, eax
    mov al, row
    mul cl
    add al, col
    mov ebx, pOldId
    mov byte ptr [ebx], al
    
    ;
    ; �����ж����������µ������Ƿ�Ϊ��, ���Ϊ����������ƶ�
    ;
    mov ebx, offset CurBlocks
    mov ecx, 6
    xor edx, edx
    
    ; ���
    .if col > 0
        xor eax, eax        
        mov al, row
        mul cl
        add al, col
        dec al
        mov dl, [ebx][eax]
        .if dl == -1
            mov ebx, pNewId
            mov byte ptr [ebx], al
            ret
        .endif
    .endif
    
    ; �ϱ�
    .if row > 0
        xor eax, eax
        mov al, row
        dec al
        mul cl
        add al, col
        mov dl, [ebx][eax]
        .if dl == -1
            mov ebx, pNewId
            mov byte ptr [ebx], al
            ret
        .endif
    .endif
    
    ; �ұ�
    .if col < 5
        xor eax, eax
        mov al, row
        mul cl
        add al, col
        inc al
        mov dl, [ebx][eax]
        .if dl == -1
            mov ebx, pNewId
            mov byte ptr [ebx], al
            ret
        .endif
    .endif
    
    ; �±�
    .if row < 2
        xor eax, eax
        mov al, row
        inc al
        mul cl
        add al, col
        mov dl, [ebx][eax]
        .if dl == -1
            mov ebx, pNewId
            mov byte ptr [ebx], al
            ret
        .endif
    .endif
    
    ; �� / �� / �� / ���������ǿ�, ��ǰ����������ͼ�����ƶ�
    mov ebx, pNewId
    mov byte ptr [ebx], -1

    ret
TranMousePos endp

;-------------------------------------------------------------------------------
; ������Ϸ����ƶ�
;-------------------------------------------------------------------------------
DealMouseMove proc posX:DWORD, posY:DWORD
    local oldId:byte
    local newId:byte    
    ;
    ; �ж������ָ�����ڵ���ͼ�Ƿ���ƶ�
    ; �������������ͼ���ƶ�����ʾ��ָ���, ������ʾ��ͨ���
    ;
    invoke TranMousePos, posX, posY, addr oldId, addr newId
        
    .if newId != -1
        invoke GetCursor
        .if eax != FingerCursor
            invoke SetCursor, FingerCursor
        .endif
    .else
        invoke GetCursor
        .if eax != NormalCursor
            invoke SetCursor, NormalCursor
        .endif
    .endif        
     
    ret
DealMouseMove endp

;-------------------------------------------------------------------------------
; ������Ϸ��굥��
;-------------------------------------------------------------------------------
DealMouseClick proc uses ebx, posX:DWORD, posY:DWORD
    local oldId:byte
    local newId:byte
    ;
    ; �ж������ָ�����ڵ�ͼƬ���Ƿ���ƶ�
    ; �������������ͼ���ƶ�����ͼ�ƶ����µ�����
    ;
    invoke TranMousePos, posX, posY, addr oldId, addr newId

    .if newId != -1
        xor eax, eax
        xor ecx, ecx        
        mov ebx, offset CurBlocks        
        mov cl, oldId
        mov al, [ebx+ecx]
        mov byte ptr [ebx+ecx], -1
        mov cl, newId
        mov [ebx+ecx], al
        
        ; ���߲����� 1
        inc UsedStep                
        .if UsedStep > 999
            mov UsedStep, 0
        .endif
        
        ; ��ʹ��Ϸ�ػ�
        invoke InvalidateRect, MainWndHdl, NULL, FALSE 
        invoke SetCursor, NormalCursor
        
        ; ������ͼ�ƶ�����
        invoke PlaySound, offset StrStepSound, AppInstance, SND_FILENAME or SND_ASYNC
        
        ;
        ; �ж��Ƿ����
        ;
        xor ecx, ecx
        .while ecx < 17
            .break .if cl != [ebx+ecx]
            inc ecx
        .endw
        
        ; ���ǰ 17 ����ͼ���Ƶ��˶�Ӧ��ȷ��λ��, ������ǰΪ�ڳ���λ�ĵ�
        ; 18 ����ͼ( ���Ϊ 17 ), ͬʱ, ������ɱ�־
        .if ecx == 17
            mov eax, 17
            mov [ebx+ecx], al
            mov eax, TRUE 
            mov IsFinish, eax

            invoke InvalidateRect, MainWndHdl, NULL, FALSE 
            invoke MessageBox, MainWndHdl, offset StrIsFinish, offset StrMessageBoxInfo,
                   MB_OK or MB_ICONINFORMATION or MB_APPLMODAL                       
        .endif
        
    .endif
    
    ret
DealMouseClick endp

;-------------------------------------------------------------------------------
; ������Ϸ��ʱ���ź�
;-------------------------------------------------------------------------------
DealTimerSignal proc timerId:DWORD    
    mov eax, timerId
    .if eax == TimerId && IsFinish == FALSE
        
        ; ����ʱ��� 1
        inc UsedTime
        .if UsedTime > 999
            mov UsedTime, 0
        .endif
        
        ; ��ʹ��Ϸ�ػ�
        invoke InvalidateRect, MainWndHdl, NULL, FALSE 
        
    .endif    
    ret
DealTimerSignal endp

;-------------------------------------------------------------------------------
; ��ʼ����Ϸ
;-------------------------------------------------------------------------------
InitGame proc   
    local hdc:HDC
    
    ; ��ʼ����Ϸ����
    mov CurPicture, 1
    mov UsedTime, 0
    mov UsedStep, 0
    mov IsFinish, FALSE
    mov PictureBM, NULL       
    
    ; ��ʼ��Ϸԭͼ�豸����
    invoke GetDC, MainWndHdl    
    mov hdc, eax       
    
    invoke CreateCompatibleDC, hdc
    .if ( !eax )
        invoke MessageBox, MainWndHdl, offset StrHdcError, offset StrMessageBoxError,
               MB_OK or MB_ICONSTOP or MB_APPLMODAL
        invoke ExitProcess, 0
    .endif
    mov	PictureDc, eax
    
    invoke ReleaseDC, MainWndHdl, hdc
    
    ; ��ʼ����ɫ
    invoke GetSysColor, COLOR_3DFACE
    mov BackClr, eax
    mov eax, 0h
    mov FrameClr, eax    
    invoke GetSysColor, COLOR_3DHIGHLIGHT
    mov LightClr, eax
    invoke GetSysColor, COLOR_3DDKSHADOW
    mov ShadowClr, eax
    mov eax, 0h
    mov FontFtClr, eax
    mov eax, 0ffffffh
    mov FontBkClr, eax

    ; ��ʼ����ʱ��
    invoke SetTimer, MainWndHdl, TimerId, 1000, NULL
    
    ; ��ʼ������    
    invoke CreateFont, 12, 0, 0, 0, FW_NORMAL, 0, 0, 0, ANSI_CHARSET, \ 
                       OUT_CHARACTER_PRECIS, CLIP_DEFAULT_PRECIS, \ 
                       DEFAULT_QUALITY, FF_DONTCARE, \ 
                       offset FontName
    mov FontHdl, eax        
    
    ; ��ʼ�������
    invoke LoadCursor, AppInstance, IDC_NORMAL
    mov NormalCursor, eax
    invoke LoadCursor, AppInstance, IDC_FINGER
    mov FingerCursor, eax        

    ret
InitGame endp

;-------------------------------------------------------------------------------
; ������Ϸ
;-------------------------------------------------------------------------------
ExitGame proc

    ; �ͷ���Ϸ��Դ  
    .if PictureDc
        invoke DeleteDC, PictureDc
    .endif
    .if PictureBM
        invoke DeleteObject, PictureBM
    .endif
    .if TimerId
        invoke KillTimer, MainWndHdl, TimerId
    .endif
    .if FontHdl
        invoke DeleteObject, FontHdl
    .endif

    ret
ExitGame endp

;-------------------------------------------------------------------------------
; ���ڶԻ������
;-------------------------------------------------------------------------------
AboutDlgProc proc hWnd:HWND, msg:UINT, wParam:WPARAM, lParam:LPARAM
    .if	msg == WM_CLOSE
        invoke EndDialog, hWnd, NULL
    .elseif	msg == WM_INITDIALOG
        invoke	LoadIcon, AppInstance, IDI_APP
        invoke	SendMessage, hWnd, WM_SETICON, ICON_BIG, eax
    .elseif msg == WM_COMMAND
        mov	eax, wParam
        .if	ax == IDOK
            invoke	EndDialog, hWnd, NULL
        .endif
    .else
        mov	eax, FALSE
        ret
    .endif
    
    xor lParam, 0h
    mov	eax, TRUE
    ret
AboutDlgProc endp

;-------------------------------------------------------------------------------
; �����ڹ���
;-------------------------------------------------------------------------------
MainWndProc proc hWnd:HWND, msg:UINT, wParam:WPARAM, lParam:LPARAM
    local paintStruct:PAINTSTRUCT 
    
    ;
    ; ���ڴ���ʱ������س�ʼ��
    ;
    .if msg == WM_CREATE
        mov eax, hWnd
        mov MainWndHdl, eax
        invoke InitGame
        invoke StartPicture, TRUE
        
    ;
    ; �˵�����
    ;
    .elseif msg == WM_COMMAND
        mov eax, wParam            
        .if ax == IDM_PREV_PICTURE
            .if CurPicture == 1
                mov ecx, TotalPicture
                mov CurPicture, ecx
            .else
                dec CurPicture                    
            .endif
            invoke StartPicture, TRUE    
        .elseif ax == IDM_NEXT_PICTURE
            mov ecx, TotalPicture
            .if CurPicture == ecx
                mov CurPicture, 1
            .else
                inc CurPicture                
            .endif
            invoke StartPicture, TRUE    
        .elseif ax == IDM_RESTART_PICTURE
            invoke MessageBox, hWnd, offset StrRestartPicture, offset StrMessageBoxInfo,
                   MB_OKCANCEL or MB_ICONQUESTION or MB_APPLMODAL
            .if eax == IDOK
                invoke StartPicture, FALSE
            .endif            
        .elseif ax == IDM_ABOUT
            invoke DialogBoxParam, AppInstance, offset IDD_ABOUT, hWnd, \
                   offset AboutDlgProc, NULL                   
        .elseif ax == IDM_EXIT
            invoke DestroyWindow, hWnd            
        .endif
           
    ;
    ; ����ƶ���Ϣ, �������������Ϸ���������̬�ı������
    ;
    .elseif msg == WM_MOUSEMOVE
        mov eax, lParam
        and eax, 0FFFFh
        mov ecx, lParam
        shr ecx, 16
        invoke DealMouseMove, eax, ecx
    
    ;
    ; ��굥����Ϣ, �������������Ϸ��������ƶ���ͼ
    ;
    .elseif msg == WM_LBUTTONDOWN 
        mov eax, lParam 
        and eax, 0FFFFh
        mov ecx, lParam
        shr ecx, 16
        invoke DealMouseClick, eax, ecx        
    
    ;
    ; ��ʱ����Ϣ, Ϊ��Ϸ��ʱ
    ;
    .elseif msg == WM_TIMER
        mov	eax, wParam
        invoke DealTimerSignal, eax
            
    ;
    ; �����ػ���Ϣ, �ػ�һ֡��Ϸ
    ;
    .elseif msg == WM_PAINT
        invoke BeginPaint, hWnd, addr paintStruct
        invoke DrawGame, eax
        invoke EndPaint, hWnd, addr paintStruct   
                     
    ;
    ; ��������ʾ��Ϣ
    ;
    .elseif msg == WM_NOTIFY
        mov	ecx, lParam
        .if	[ ecx + NMHDR.code ] == TTN_NEEDTEXT
            assume ecx : ptr TOOLTIPTEXT
            mov	eax, [ecx].hdr.idFrom
            mov	[ecx].lpszText, eax
            push AppInstance
            pop	[ecx].hinst
            assume ecx : nothing
        .endif   
             
    ;
    ; ������Ϸ / ϵͳĬ�ϴ��ڴ������
    ;
    .elseif msg == WM_DESTROY    
        invoke ExitGame
        invoke PostQuitMessage, NULL 
    .else
        invoke DefWindowProc, hWnd, msg, wParam, lParam
        ret
    .endif
    
    xor eax, eax
    ret
MainWndProc endp

;-------------------------------------------------------------------------------
; ��ڴ���
;-------------------------------------------------------------------------------
start:
    ;
    ; ��ʼ��
    ;
    invoke InitCommonControls
    invoke GetModuleHandle, NULL
    mov AppInstance, eax    
    invoke GetCommandLine
    mov AppCmdLine, eax    
    
    ;
    ; ע�ᴰ����
    ;
    mov MainWndCls.cbSize, sizeof WNDCLASSEX
    mov MainWndCls.style, CS_HREDRAW or CS_VREDRAW
    mov MainWndCls.lpfnWndProc, offset MainWndProc
    mov MainWndCls.lpszClassName, offset AppName
    mov MainWndCls.hbrBackground, COLOR_BTNFACE + 1
    mov MainWndCls.cbClsExtra, NULL
    mov MainWndCls.cbWndExtra, NULL
    mov eax, AppInstance
    mov MainWndCls.hInstance, eax
    invoke LoadIcon, AppInstance, IDI_APP
    mov MainWndCls.hIcon, eax
    mov MainWndCls.hIconSm, eax
    mov MainWndCls.hCursor, NULL
    invoke RegisterClassEx, offset MainWndCls
    
    ;
    ; ����Ļ�����Ĵ�������
    ;
        
    ; ���������Ŀͻ�����С�������贴���Ĵ��ڴ�С
    ; �����Զ���Ӧ����ϵͳ���, ����ϵͳ����Ϊ Windows Xp �� Windows �������
    mov eax, ClientRect.left
    mov MainWndRect.left, eax
    mov eax, ClientRect.top
    mov MainWndRect.top, eax
    mov eax, ClientRect.right
    mov MainWndRect.right, eax
    mov eax, ClientRect.bottom
    mov MainWndRect.bottom, eax
    mov MainWndStyle, WS_CAPTION or WS_MINIMIZEBOX or WS_SYSMENU or WS_BORDER
    invoke AdjustWindowRect, offset MainWndRect, MainWndStyle, TRUE
    mov eax, MainWndRect.right
    sub eax, MainWndRect.left
    mov MainWndWidth, eax
    mov eax, MainWndRect.bottom
    sub eax, MainWndRect.top
    mov MainWndHeight, eax
    
    ; ������Ļ����λ��
    invoke GetSystemMetrics, SM_CXSCREEN
    shr eax, 1
    mov ecx, MainWndWidth
    shr ecx, 1
    sub eax, ecx
    mov MainWndPosX, eax    
    invoke GetSystemMetrics, SM_CYSCREEN
    shr eax, 1
    mov ecx, MainWndHeight
    shr ecx, 1
    sub eax, ecx
    mov MainWndPosY, eax
    
    ; ���ز˵�
    invoke LoadMenu, AppInstance, IDM_APP
    
    ; ��������
    invoke CreateWindowEx, NULL, offset AppName, offset AppName, MainWndStyle, \
           MainWndPosX, MainWndPosY, MainWndWidth, MainWndHeight, \
           NULL, eax, AppInstance, NULL
    
    ;
    ; ���������� / ���ع�� / ��ʾ���´���
    ;
    invoke CreateToolbarEx, MainWndHdl, \
           WS_VISIBLE or TBSTYLE_FLAT or TBSTYLE_TOOLTIPS, \
           NULL, TBButtonNum, AppInstance, IDB_TOOLBAR, offset TBButton, \
           TBButtonNum, 20, 20, 20, 20, sizeof TBBUTTON
    
    invoke LoadCursor, AppInstance, IDC_NORMAL
    invoke SetCursor, eax
          
    invoke ShowWindow, MainWndHdl, SW_SHOWNORMAL
    invoke UpdateWindow, MainWndHdl
        
    ;
    ; ������Ϣѭ��
    ;
    .while TRUE
        invoke GetMessage, offset MainWndMsg, NULL, 0, 0
        .break .if eax == 0
        invoke TranslateMessage, offset MainWndMsg
        invoke DispatchMessage, offset MainWndMsg
    .endw
    
    invoke ExitProcess, MainWndMsg.wParam
end start