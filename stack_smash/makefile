CC = cc
CFLAGS = -O0 -g -Wall -fno-omit-frame-pointer -fno-stack-protector -fno-pie -fcf-protection=none
LDFLAGS = -no-pie

test: test.o
	$(CC) $(LDFLAGS) -o test test.o

test.o: test.c
	$(CC) $(CFLAGS) -c test.c -o test.o

clean:
	rm -f test.o test

.PHONY: clean
