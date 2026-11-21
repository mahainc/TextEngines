#ifndef BERGAMOT_FFI_H
#define BERGAMOT_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct bergamot_engine bergamot_engine;

// On failure returns NULL and, when error is non-NULL, stores a message to free with bergamot_free_string.
bergamot_engine *bergamot_create(const char *model, const char *lex, const char *vocab, int threads, char **error);
// Returns a malloc'd UTF-8 string; free with bergamot_free_string.
char *bergamot_translate(bergamot_engine *engine, const char *utf8, char **error);
void bergamot_free_string(char *string);
void bergamot_destroy(bergamot_engine *engine);

#ifdef __cplusplus
}
#endif

#endif
