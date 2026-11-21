#include "bergamot_ffi.h"

#include <cstdlib>
#include <cstring>
#include <future>
#include <memory>
#include <mutex>
#include <new>
#include <string>

#include "common/logging.h"
#include "translator/parser.h"
#include "translator/response.h"
#include "translator/response_options.h"
#include "translator/service.h"
#include "translator/translation_model.h"

namespace bergamot = marian::bergamot;

// Members are destroyed in reverse order: the service joins its workers before the model goes.
struct bergamot_engine {
  std::shared_ptr<bergamot::TranslationModel> model;
  std::unique_ptr<bergamot::AsyncService> service;
};

namespace {

char *copyString(const std::string &text) {
  char *copy = static_cast<char *>(std::malloc(text.size() + 1));
  if (copy == nullptr) throw std::bad_alloc();
  std::memcpy(copy, text.c_str(), text.size() + 1);
  return copy;
}

void report(char **error, const char *message) {
  if (error == nullptr) return;
  size_t length = std::strlen(message);
  *error = static_cast<char *>(std::malloc(length + 1));
  if (*error != nullptr) std::memcpy(*error, message, length + 1);
}

// Marian's ABORT() calls std::abort() unless told to throw; a bad model file must not kill the app.
template <class Result, class Body>
Result guarded(char **error, Body &&body) {
  static std::once_flag once;
  try {
    std::call_once(once, [] { marian::setThrowExceptionOnAbort(true); });
    return body();
  } catch (const std::exception &exception) {
    report(error, exception.what());
  } catch (...) {
    report(error, "unknown error");
  }
  return nullptr;
}

std::string quoted(const char *path) {
  std::string result = "'";
  for (const char *c = path; *c != '\0'; ++c) result += (*c == '\'') ? std::string("''") : std::string(1, *c);
  return result + "'";
}

std::string configYAML(const char *model, const char *lex, const char *vocab) {
  return "models:\n  - " + quoted(model) +
         "\nvocabs:\n  - " + quoted(vocab) + "\n  - " + quoted(vocab) +
         "\nshortlist:\n  - " + quoted(lex) + "\n  - false\n"
         "beam-size: 1\n"
         "normalize: 1.0\n"
         "word-penalty: 0\n"
         "max-length-break: 128\n"
         "mini-batch-words: 1024\n"
         "workspace: 128\n"
         "max-length-factor: 2.0\n"
         "skip-cost: true\n"
         "quiet: true\n"
         "quiet-translation: true\n"
         "gemm-precision: int8shiftAlphaAll\n"
         "alignment: soft\n";
}

}  // namespace

extern "C" {

bergamot_engine *bergamot_create(const char *model, const char *lex, const char *vocab, int threads, char **error) {
  if (model == nullptr || lex == nullptr || vocab == nullptr || threads < 1) {
    report(error, "model, lex and vocab must be non-NULL and threads >= 1");
    return nullptr;
  }
  return guarded<bergamot_engine *>(error, [&] {
    bergamot::AsyncService::Config config;
    config.numWorkers = static_cast<size_t>(threads);
    config.cacheSize = 0;
    config.logger.level = "off";
    auto engine = std::make_unique<bergamot_engine>();
    engine->service = std::make_unique<bergamot::AsyncService>(config);
    auto options = bergamot::parseOptionsFromString(configYAML(model, lex, vocab), /*validate=*/false);
    engine->model = engine->service->createCompatibleModel(options);
    return engine.release();
  });
}

char *bergamot_translate(bergamot_engine *engine, const char *utf8, char **error) {
  if (engine == nullptr || utf8 == nullptr) {
    report(error, "engine and text must be non-NULL");
    return nullptr;
  }
  return guarded<char *>(error, [&] {
    std::promise<bergamot::Response> promise;
    auto future = promise.get_future();
    engine->service->translate(
        engine->model, std::string(utf8),
        [&promise](bergamot::Response &&response) { promise.set_value(std::move(response)); },
        bergamot::ResponseOptions());
    return copyString(future.get().target.text);
  });
}

void bergamot_free_string(char *string) { std::free(string); }

void bergamot_destroy(bergamot_engine *engine) { delete engine; }

}  // extern "C"
