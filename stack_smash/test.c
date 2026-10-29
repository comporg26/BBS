#include <stdio.h>
#include <stdint.h>

__attribute__((noinline))
void function(int a, int b, int c)
{
    uintptr_t *ret;
    ret = (uintptr_t *)42;
    /* Find our own location on the stack */
    ret = (uintptr_t *)&ret;

    /* Move to the saved return address */
    ret = ret + 3;

    /* Skip the instruction x = 1 */
    *ret = *ret + 7;
}

int main(void)
{
    int x;

    x = 0;
    function(1, 2, 3);
    x += 1;
    printf("%d\n", x);

    return 0;
}

