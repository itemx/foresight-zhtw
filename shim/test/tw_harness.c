// Checks the Simplified -> Traditional conversion: Chinese is converted with
// Taiwan phrases, Japanese and English pass through untouched.
// Build and run:  clang -o /tmp/tw shim/test/tw_harness.c shim/sensevoice_engine.c && /tmp/tw
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../sensevoice_engine.h"

void logf_(const char *fmt, ...) { va_list ap; va_start(ap, fmt); vfprintf(stderr, fmt, ap); va_end(ap); fputc('\n', stderr); }

static void check(const char *in, const char *lang, const char *want) {
  char *got = sv_convert(strdup(in), lang);
  if (strcmp(got, want) != 0) { fprintf(stderr, "FAIL %s [%s] -> %s, want %s\n", in, lang ? lang : "", got, want); exit(1); }
  free(got);
}

int main(void) {
  sv_available(getenv("HOME"));  // sets the OpenCC paths; SenseVoice itself need not be installed
  sv_load_opencc();
  check("软件开发的服务器", "<|zh|>", "軟體開發的伺服器");  // s2twp: Taiwan phrases
  check("头发后面", "<|zh|>", "頭髮後面");                   // one-to-many characters
  check("日本語の学校", "<|ja|>", "日本語の学校");           // Japanese kanji kept
  check("日本語の学校", "", "日本語の学校");                 // no label: kana guard
  check("hello world", "<|en|>", "hello world");
  puts("ok");
  return 0;
}
