#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

extern uint64_t c12_run_extract(const void *, const void *, uint64_t, uint64_t,
                                void *);
extern void c12_run_copy(const void *, const void *, const void *, uint64_t,
                         uint64_t, void *, void *);
extern uint64_t c12_vlen_bytes(void);
extern uint64_t c12_vl64(uint64_t);
extern uint64_t c12_vl32(uint64_t);

enum { Guard = 64, Sentinel = 0xa5 };
static unsigned char *X, *Y, *Z, *Mem, *Returned;
static size_t Bytes;
static void illegal(int sig) {
  (void)sig;
  static const char Msg[] = "RVV/OS probe failed: SIGILL\n";
  ssize_t Written = write(STDERR_FILENO, Msg, sizeof(Msg) - 1);
  (void)Written;
  _Exit(2);
}
static void fail(const char *what) {
  fprintf(stderr, "FAIL: %s\n", what);
  exit(1);
}
static unsigned char *allocate(void) {
  void *P = NULL;
  if (posix_memalign(&P, Guard, Bytes + 2 * Guard))
    fail("allocation");
  memset(P, Sentinel, Bytes + 2 * Guard);
  return (unsigned char *)P + Guard;
}
static uint64_t read64(const unsigned char *P) {
  uint64_t V;
  memcpy(&V, P, sizeof(V));
  return V;
}
static uint32_t read32(const unsigned char *P) {
  uint32_t V;
  memcpy(&V, P, sizeof(V));
  return V;
}
static uint64_t random64(uint64_t *S) {
  *S ^= *S << 13;
  *S ^= *S >> 7;
  *S ^= *S << 17;
  return *S;
}
static void initialize(unsigned Pattern) {
  uint64_t S = UINT64_C(0x123456789abcdef) + Pattern;
  for (size_t I = 0; I < Bytes; I += 8) {
    uint64_t A = random64(&S), B = random64(&S), C = random64(&S);
    if (Pattern == 0) A = B = C = 0;
    if (Pattern == 1) A = B = C = UINT64_MAX;
    if (Pattern == 2) { A = UINT64_C(0x800000007fffffff); B = 1; }
    if (Pattern == 3) { A = I; B = UINT64_MAX - I; }
    memcpy(X + I, &A, 8);
    memcpy(Y + I, &B, 8);
    memcpy(Z + I, &C, 8);
  }
}
static void guards(const unsigned char *P) {
  for (size_t I = 0; I < Guard; ++I)
    if ((P - Guard)[I] != Sentinel || P[Bytes + I] != Sentinel)
      fail("buffer guard changed");
}
static void check_memory(int Copy, uint64_t Cond, uint64_t Avl) {
  size_t Width = Copy && !Cond ? 4 : 8;
  uint64_t Vl = Width == 4 ? c12_vl32(7) : c12_vl64(Cond ? Avl : 7);
  for (size_t I = 0; I < Vl; ++I) {
    if (Width == 8) {
      uint64_t A = read64(X + I * 8), B = read64(Y + I * 8);
      if (read64(Mem + I * 8) != (Cond ? A + B : A - B))
        fail("e64 active memory prefix");
    } else if (read32(Mem + I * 4) !=
               (uint32_t)(read32(X + I * 4) + read32(Y + I * 4)))
      fail("e32 active memory prefix");
  }
  for (size_t I = Vl * Width; I < Bytes; ++I)
    if (Mem[I] != Sentinel) fail("inactive memory tail changed");
  guards(Mem);
}
static void correctness(void) {
  uint64_t Max = Bytes / 8;
  uint64_t Avls[] = {0, 1, 2, 7, Max - 1, Max, Max + 1,
                     2 * Max - 1, 2 * Max, UINT64_MAX};
  for (unsigned Pattern = 0; Pattern < 260; ++Pattern) {
    initialize(Pattern);
    for (size_t I = 0; I < sizeof(Avls) / sizeof(Avls[0]); ++I)
      for (uint64_t Cond = 0; Cond < 2; ++Cond) {
        uint64_t Avl = Avls[I];
        if (!Cond || Avl) {
          memset(Mem, Sentinel, Bytes);
          uint64_t Got = c12_run_extract(X, Y, Cond, Avl, Mem);
          uint64_t A = read64(X), B = read64(Y);
          if (Got != (Cond ? A + B : A - B)) fail("extract lane zero");
          check_memory(0, Cond, Avl);
        }
        memset(Mem, Sentinel, Bytes);
        memset(Returned, Sentinel, Bytes);
        c12_run_copy(X, Y, Z, Cond, Avl, Mem, Returned);
        check_memory(1, Cond, Avl);
        if (memcmp(Returned, Z, Bytes)) fail("copy whole-register result");
        guards(Returned);
        guards(X); guards(Y); guards(Z);
      }
  }
}
static uint64_t nanoseconds(const struct timespec *T) {
  return (uint64_t)T->tv_sec * UINT64_C(1000000000) + (uint64_t)T->tv_nsec;
}
int main(int Argc, char **Argv) {
  struct sigaction SA;
  memset(&SA, 0, sizeof(SA));
  SA.sa_handler = illegal;
  sigemptyset(&SA.sa_mask);
  if (sigaction(SIGILL, &SA, NULL)) fail("sigaction");
  uint64_t Vb = c12_vlen_bytes();
  if (Vb < 16 || Vb > 1048576 || Vb % 8) fail("unsupported vlenb");
  Bytes = (size_t)Vb;
  if (c12_vl64(Bytes / 8) != Bytes / 8 || c12_vl32(Bytes / 4) != Bytes / 4)
    fail("e32/e64 m1 RVV/OS probe");
  if (Argc == 2 && !strcmp(Argv[1], "--probe")) {
    printf("probe=PASS,vlenb=%zu\n", Bytes);
    return 0;
  }
  X = allocate(); Y = allocate(); Z = allocate();
  Mem = allocate(); Returned = allocate();
  correctness();
  if (Argc == 1 || (Argc == 2 && !strcmp(Argv[1], "--check"))) {
    printf("correctness=PASS,vlenb=%zu,patterns=260\n", Bytes);
    return 0;
  }
  if (Argc != 4 || strcmp(Argv[1], "--bench") ||
      (strcmp(Argv[2], "extract") && strcmp(Argv[2], "copy")))
    fail("usage: --probe | --check | --bench extract|copy ITERS");
  char *End;
  errno = 0;
  uint64_t Iters = strtoull(Argv[3], &End, 10);
  if (errno || !Iters || *End || Argv[3][0] == '-') fail("invalid ITERS");
  int Copy = !strcmp(Argv[2], "copy");
  initialize(17);
  uint64_t A = read64(X), B = read64(Y), C = read64(Z);
  uint64_t Expected = Copy ? C * Iters :
      (A - B) * (Iters / 2 + Iters % 2) + (A + B) * (Iters / 2);
  uint64_t Sum = 0, Avl = Bytes / 8;
  struct timespec Start, Stop;
  if (clock_gettime(CLOCK_MONOTONIC_RAW, &Start)) fail("clock start");
  if (Copy)
    for (uint64_t I = 0; I < Iters; ++I) {
      c12_run_copy(X, Y, Z, I & 1, Avl, Mem, Returned);
      Sum += read64(Returned);
    }
  else
    for (uint64_t I = 0; I < Iters; ++I)
      Sum += c12_run_extract(X, Y, I & 1, Avl, Mem);
  if (clock_gettime(CLOCK_MONOTONIC_RAW, &Stop)) fail("clock stop");
  if (Sum != Expected) fail("timed checksum");
  printf("%s,%" PRIu64 ",%zu,%" PRIu64 ",%" PRIu64 ",PASS\n",
         Argv[2], Iters, Bytes, nanoseconds(&Stop) - nanoseconds(&Start), Sum);
  return 0;
}
