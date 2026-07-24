#include "qwentts_napi.h"
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <sys/stat.h>

#include "napi/native_api.h"
#include "hilog/log.h"

#undef LOG_TAG
#define LOG_TAG "QwenTTS"

#define LOGI(...) OH_LOG_INFO(LOG_APP, __VA_ARGS__)
#define LOGE(...) OH_LOG_ERROR(LOG_APP, __VA_ARGS__)

namespace qwentts {

static std::string gBinaryPath;
static std::string gModelDir;

// ============ 工具函数 ============

static std::string GetStringArg(napi_env env, napi_value value) {
  size_t len = 0;
  napi_get_value_string_utf8(env, value, nullptr, 0, &len);
  std::string result(len, '\0');
  napi_get_value_string_utf8(env, value, &result[0], len + 1, &len);
  return result;
}

static napi_value CreateInt32(napi_env env, int32_t value) {
  napi_value result;
  napi_create_int32(env, value, &result);
  return result;
}

static bool FileExists(const std::string &path) {
  FILE *f = fopen(path.c_str(), "r");
  if (f) {
    fclose(f);
    return true;
  }
  return false;
}

static int RunCommand(const std::string &cmd) {
  LOGI("RunCommand: %{public}s", cmd.c_str());
  FILE *pipe = popen(cmd.c_str(), "r");
  if (!pipe) {
    LOGE("popen failed");
    return -1;
  }
  char buffer[256];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    LOGI("%{public}s", buffer);
  }
  return pclose(pipe);
}

static bool CopyFile(const std::string &src, const std::string &dst) {
  FILE *srcFile = fopen(src.c_str(), "rb");
  if (!srcFile) {
    LOGE("Failed to open src: %{public}s", src.c_str());
    return false;
  }
  FILE *dstFile = fopen(dst.c_str(), "wb");
  if (!dstFile) {
    fclose(srcFile);
    LOGE("Failed to open dst: %{public}s", dst.c_str());
    return false;
  }
  char buffer[4096];
  size_t n;
  while ((n = fread(buffer, 1, sizeof(buffer), srcFile)) > 0) {
    if (fwrite(buffer, 1, n, dstFile) != n) {
      fclose(srcFile);
      fclose(dstFile);
      return false;
    }
  }
  fclose(srcFile);
  fclose(dstFile);
  return true;
}

static napi_value QwenTtsPrepareBinary(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 2) {
    LOGE("QwenTtsPrepareBinary needs 2 arguments: srcPath, destPath");
    return CreateInt32(env, -1);
  }

  std::string srcPath = GetStringArg(env, args[0]);
  std::string destPath = GetStringArg(env, args[1]);
  LOGI("QwenTtsPrepareBinary src=%{public}s dst=%{public}s", srcPath.c_str(), destPath.c_str());

  if (!CopyFile(srcPath, destPath)) {
    return CreateInt32(env, -2);
  }

  if (chmod(destPath.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH) != 0) {
    LOGE("chmod failed for %{public}s", destPath.c_str());
    return CreateInt32(env, -3);
  }

  return CreateInt32(env, 0);
}

// ============ 同步方法 ============

static napi_value QwenTtsInit(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 2) {
    LOGE("QwenTtsInit needs 2 arguments: binaryPath, modelDir");
    return CreateInt32(env, -1);
  }

  gBinaryPath = GetStringArg(env, args[0]);
  gModelDir = GetStringArg(env, args[1]);
  LOGI("QwenTtsInit binary=%{public}s modelDir=%{public}s", gBinaryPath.c_str(), gModelDir.c_str());

  if (!FileExists(gBinaryPath)) {
    LOGE("TTS binary not found: %{public}s", gBinaryPath.c_str());
    return CreateInt32(env, -2);
  }
  if (!FileExists(gModelDir)) {
    LOGE("Model dir not found: %{public}s", gModelDir.c_str());
    return CreateInt32(env, -3);
  }

  return CreateInt32(env, 0);
}

static napi_value QwenTtsRelease(napi_env env, napi_callback_info info) {
  LOGI("QwenTtsRelease");
  gBinaryPath.clear();
  gModelDir.clear();
  return nullptr;
}

// ============ 异步合成 ============

struct SynthesizeAsyncContext {
  napi_env env;
  napi_async_work work;
  napi_deferred deferred;

  std::string text;
  std::string voice;
  std::string language;
  std::string outputPath;

  int32_t resultCode = 0;
  std::string resultMessage;
};

static void SynthesizeExecute(napi_env env, void *data) {
  auto *ctx = reinterpret_cast<SynthesizeAsyncContext *>(data);

  if (gBinaryPath.empty()) {
    ctx->resultCode = -1;
    ctx->resultMessage = "Qwen TTS 未初始化";
    return;
  }

  // 组装命令行。注意：text 中可能包含特殊字符，生产环境需要转义。
  std::string cmd = gBinaryPath +
                    " -d \"" + gModelDir + "\"" +
                    " --text \"" + ctx->text + "\"" +
                    " --speaker \"" + ctx->voice + "\"" +
                    " --language \"" + ctx->language + "\"" +
                    " -o \"" + ctx->outputPath + "\"";

  LOGI("SynthesizeExecute: %{public}s", cmd.c_str());
  int rc = RunCommand(cmd);
  if (rc != 0) {
    ctx->resultCode = rc;
    ctx->resultMessage = "qwen_tts 进程返回非零退出码: " + std::to_string(rc);
    return;
  }

  if (!FileExists(ctx->outputPath)) {
    ctx->resultCode = -2;
    ctx->resultMessage = "未生成输出音频: " + ctx->outputPath;
    return;
  }

  ctx->resultCode = 0;
}

static void SynthesizeComplete(napi_env env, napi_status status, void *data) {
  auto *ctx = reinterpret_cast<SynthesizeAsyncContext *>(data);
  napi_value result;
  if (ctx->resultCode == 0) {
    napi_create_string_utf8(env, ctx->outputPath.c_str(), NAPI_AUTO_LENGTH, &result);
    napi_resolve_deferred(env, ctx->deferred, result);
  } else {
    napi_create_string_utf8(env, ctx->resultMessage.c_str(), NAPI_AUTO_LENGTH, &result);
    napi_reject_deferred(env, ctx->deferred, result);
  }
  napi_delete_async_work(env, ctx->work);
  delete ctx;
}

static napi_value QwenTtsSynthesize(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 4) {
    napi_value promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &promise);
    napi_value err;
    napi_create_string_utf8(env, "需要 4 个参数: text, voice, language, outputPath", NAPI_AUTO_LENGTH, &err);
    napi_reject_deferred(env, deferred, err);
    return promise;
  }

  auto *ctx = new SynthesizeAsyncContext();
  ctx->env = env;
  ctx->text = GetStringArg(env, args[0]);
  ctx->voice = GetStringArg(env, args[1]);
  ctx->language = GetStringArg(env, args[2]);
  ctx->outputPath = GetStringArg(env, args[3]);

  napi_value resourceName;
  napi_create_string_utf8(env, "QwenTtsSynthesize", NAPI_AUTO_LENGTH, &resourceName);

  napi_value promise;
  napi_create_promise(env, &ctx->deferred, &promise);
  napi_create_async_work(env, nullptr, resourceName, SynthesizeExecute, SynthesizeComplete,
                         reinterpret_cast<void *>(ctx), &ctx->work);
  napi_queue_async_work(env, ctx->work);

  return promise;
}

// ============ 模块导出 ============

static napi_value QwenTtsExport(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
    {"init", nullptr, QwenTtsInit, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"prepareBinary", nullptr, QwenTtsPrepareBinary, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"synthesize", nullptr, QwenTtsSynthesize, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"release", nullptr, QwenTtsRelease, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  return exports;
}

static napi_module qwenttsModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = QwenTtsExport,
  .nm_modname = "qwentts",
  .nm_priv = nullptr,
  .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterQwenTtsModule() {
  napi_module_register(&qwenttsModule);
}

} // namespace qwentts
