#include <stdio.h>
#include "../include/hde64.h"

char fmt[] = "\n"
  " mov rax,0x1122334455667788\n\n"
  "  length of command:  0x%02x\n"
  "  immediate64:        0x%08x%08x\n";

unsigned char code[] = {0x48,0xb8,0x88,0x77,0x66,0x55,0x44,0x33,0x22,0x11};

int main(void)
{
    hde64s hs;

    unsigned int length = hde64_disasm(code,&hs);

    if (hs.flags & F_ERROR)
        printf("Invalid instruction !\n");
    else
        printf(fmt,length,(uint32_t)(hs.imm.imm64 >> 32),
                (uint32_t)hs.imm.imm64);

    return 0;
}
