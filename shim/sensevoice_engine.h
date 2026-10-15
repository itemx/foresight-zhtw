#pragma once

typedef struct {
  char *text;          // malloc'ed; ownership passes to the result list
  long long start_us;  // relative to stream start
  long long end_us;
} SvResult;

// Returns 1 if the SenseVoice model, VAD model and sherpa-onnx library are installed.
int sv_available(const char *home);
// Loads sherpa-onnx and the models on a background thread.
void sv_start_loading(void);
// Feeds 48 kHz mono float audio for a stream; writes finished phrases to out.
// Returns the number of results, or -1 if the engine failed to load.
int sv_push(int stream, const float *samples, int n, SvResult *out, int max_out);
// Flushes the stream at the end of a session and resets it.
int sv_finish(int stream, SvResult *out, int max_out);
// Converts a Chinese phrase (per SenseVoice's lang label, e.g. "<|zh|>") from
// Simplified to Traditional with OpenCC. Other languages and text with kana pass
// through. Takes ownership of text; returns malloc'ed text.
char *sv_convert(char *text, const char *lang);
// Loads OpenCC (done by sv_start_loading; exposed for tests). Paths come from sv_available.
void sv_load_opencc(void);
