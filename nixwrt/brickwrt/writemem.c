#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <unistd.h>

void die(int argc, char *argv[]) {
  fprintf(stderr, "Usage: %s OFFSET\nWrite standard input to /dev/mem at OFFSET\n", argv[0]);
  exit(1);
}

#define BLOCKSIZE (8 * 1024)
int main(int argc, char *argv[]) {
  if(argc != 2) die(argc, argv);
  long offset = strtol(argv[1], NULL, 0);
  if(offset <= 0) die(argc, argv);

  int fd = open("/dev/mem", O_WRONLY);
  if(fd<0) {
    perror("/dev/mem");
    exit(1);
  }
  lseek(fd, offset, SEEK_SET);

  char *buf = malloc(BLOCKSIZE);
  int bytes_read, bytes_written;


  do {
    bytes_written = 0;
    (void) write(2, ".", 1);
    bytes_read = read(0, buf, BLOCKSIZE);
    printf("%d %d\n", bytes_read, bytes_written);
    if(bytes_read<1) break;
    while(bytes_written < bytes_read) {
      int b = write(fd, buf, bytes_read - bytes_written);
      if(b>0) {
        bytes_written += b;
      } else if (b< 0) {
        perror("write failed");
        exit(1);
      }
    }
  } while(1);

  close(fd);
  return 0;
}
