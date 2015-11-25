module fixed.internal.uint128x8664;

import fixed.uint128;

version(D_InlineAsm_X86_64):

void inc128(ref uint128 x)
{
    asm { naked; }

    version (Win64) asm {
        mov RAX, qword ptr [RCX];
        mov RDX, qword ptr [RCX + 8];
    }
    else asm {
        mov RAX, qword ptr [RDI];
        mov RDX, qword ptr [RDI + 8];
    }

    asm
    {
        add RAX, 1;
        adc RDX, 0;
    }

    version(Win64) asm {
        mov qword ptr [RCX], RAX;
        mov qword ptr [RCX + 8], RDX;
    }
    else asm {
        mov qword ptr [RDI], RAX;
        mov qword ptr [RDI + 8], RDX;
    }

    asm 
    { 
        ret; 
    }

}

void dec128(ref uint128 x)
{
    asm { naked; }

    version (Win64) asm {
        mov RAX, qword ptr [RCX];
        mov RDX, qword ptr [RCX + 8];
    }
    else asm {
        mov RAX, qword ptr [RDI];
        mov RDX, qword ptr [RDI + 8];
    }

    asm
    {
        sub RAX, 1;
        sbb RDX, 0;
    }

    version(Win64) asm {
        mov qword ptr [RCX], RAX;
        mov qword ptr [RCX + 8], RDX;
    }
    else asm {
        mov qword ptr [RDI], RAX;
        mov qword ptr [RDI + 8], RDX;
    }

    asm 
    { 
        ret; 
    }

}