module fixed.internal.uint128x8632;

import fixed.uint128;



extern(C):

version(D_InlineAsm_X86):

void inc128(ref uint128 x)
{
    asm
    {
        naked;
        mov EAX, dword ptr [ESP + 4];
        mov ECX, dword ptr [EAX];
        add ECX, 1;
        mov dword ptr [EAX], ECX;
        jnc end;
        mov EDX, dword ptr [EAX + 4];
        add EDX, 1;    
        mov dword ptr [EAX + 4], EDX;
        jnc end;
        mov ECX, dword ptr [EAX + 8];
        add ECX, 1;
        mov dword ptr [EAX + 8], ECX;
        jnc end;
        mov EDX, dword ptr [EAX + 12];
        add EDX, 1;
        mov dword ptr [EAX + 12], EDX;
    end:
        ret;
    }
}

void dec128(ref uint128 x)
{
    asm
    {
        naked;
        mov EAX, dword ptr [ESP + 4];
        mov ECX, dword ptr [EAX];
        sub ECX, 1;
        mov dword ptr [EAX], ECX;
        cmp ECX, 0xFFFFFFFF;
        jne end;
        mov EDX, dword ptr [EAX + 4];
        sub EDX, 1;      
        mov dword ptr [EAX + 4], EDX;
        cmp EDX, 0xFFFFFFFF;
        jne end;
        mov ECX, dword ptr [EAX + 8];
        sub ECX, 1;
        mov dword ptr [EAX + 8], ECX;
        cmp ECX, 0xFFFFFFFF;
        jne end;
        mov EDX, dword ptr [EAX + 12];
        sub EDX, 1;      
        mov dword ptr [EAX + 12], EDX;
    end:
        ret;
    }
}

void not128(ref uint128 x)
{
    asm
    {
        naked;
        mov EAX, [ESP + 4];
        movdqu XMM0, [EAX];
        pcmpeqd XMM1, XMM1;
        pxor XMM1, XMM0;
        movdqu [EAX], XMM1;
        ret;
    }
}

void neg128(ref uint128 x)
{
    asm
    {
        naked;
        mov EAX, [ESP + 4];
        movdqu XMM0, [EAX];
        pcmpeqd XMM1, XMM1;
        pxor XMM1, XMM0;
        pextrd ECX, XMM1, 0;
        pextrd EDX, XMM1, 1;
        add ECX, 1;
        adc EDX, 0;
        mov dword ptr [EAX], ECX;
        mov dword ptr [EAX + 4], EDX;
        pextrd ECX, XMM1, 2;
        pextrd EDX, XMM1, 3;
        adc ECX, 0;
        adc EDX, 0;
        mov dword ptr [EAX + 8], ECX;
        mov dword ptr [EAX + 12], EDX;
        ret;
    }
}

void and128(ref uint128 x, const ref uint128 y)
{
    asm
    {
        naked;
        mov ECX, [ESP + 8];
        mov EAX, [ESP + 4];
        movdqu XMM0, [EAX];
        movdqu XMM1, [ECX];
        pand XMM0, XMM1;
        movdqu [EAX], XMM0;
        ret;
    }
}

void or128(ref uint128 x, const ref uint128 y)
{
    asm
    {
        naked;
        mov ECX, [ESP + 8];
        mov EAX, [ESP + 4];
        movdqu XMM0, [EAX];
        movdqu XMM1, [ECX];
        por XMM0, XMM1;
        movdqu [EAX], XMM0;
        ret;
    }
}

void xor128(ref uint128 x, const ref uint128 y)
{
    asm
    {
        naked;
        mov ECX, [ESP + 8];
        mov EAX, [ESP + 4];
        movdqu XMM0, [EAX];
        movdqu XMM1, [ECX];
        pxor XMM0, XMM1;
        movdqu [EAX], XMM0;
        ret;
    }
}

void add128(ref uint128 x, const ref uint128 y)
{
    asm
    {
        naked;
        push EBX;
        push ESI;
        push EDI;
        mov ECX, dword ptr [ESP + 20];
        mov EAX, dword ptr [ESP + 16];
        mov EDX, dword ptr [EAX];
        mov EBX, dword ptr [ECX];
        mov ESI, dword ptr [EAX + 4];
        mov EDI, dword ptr [ECX + 4];
        add EDX, EBX;
        adc ESI, EDI;
        mov dword ptr [EAX], EDX;
        mov dword ptr [EAX + 4], ESI;
        mov EDX, dword ptr [EAX + 8];
        mov EBX, dword ptr [ECX + 8];
        mov ESI, dword ptr [EAX + 12];
        mov EDI, dword ptr [ECX + 12];
        adc EDX, EBX;
        adc ESI, EDI;
        mov dword ptr [EAX + 8], EDX;
        mov dword ptr [EAX + 12], ESI;
        pop EDI;
        pop ESI;
        pop EBX;
        ret;
    }
}

void sub128(ref uint128 x, const ref uint128 y)
{
    asm
    {
        naked;
        push EBX;
        push ESI;
        push EDI;
        mov ECX, dword ptr [ESP + 20];
        mov EAX, dword ptr [ESP + 16];
        mov EDX, dword ptr [EAX];
        mov EBX, dword ptr [ECX];
        mov ESI, dword ptr [EAX + 4];
        mov EDI, dword ptr [ECX + 4];
        sub EDX, EBX;
        sbb ESI, EDI;
        mov dword ptr [EAX], EDX;
        mov dword ptr [EAX + 4], ESI;
        mov EDX, dword ptr [EAX + 8];
        mov EBX, dword ptr [ECX + 8];
        mov ESI, dword ptr [EAX + 12];
        mov EDI, dword ptr [ECX + 12];
        sbb EDX, EBX;
        sbb ESI, EDI;
        mov dword ptr [EAX + 8], EDX;
        mov dword ptr [EAX + 12], ESI;
        pop EDI;
        pop ESI;
        pop EBX;
        ret;
    }
}

void shl128(ref uint128 x, const int y)
{
    asm
    {
        naked;
        mov ECX, dword ptr [ESP + 8];
        and ECX, 127;
        jecxz end;
        mov EAX, dword ptr [ESP + 4];
        cmp cl, 96;
        jb shift96;
        mov EDX, dword ptr [EAX];
        push EBX;
        mov EBX, dword ptr [EAX + 12];
        sub ECX, 96;


    shift96:
    end:
        ret;
    }
}

