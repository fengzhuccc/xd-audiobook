#ifndef QWENTTS_NAPI_H
#define QWENTTS_NAPI_H

#include "napi/native_api.h"

namespace qwentts {

napi_value ModuleRegister(napi_env env, napi_value exports);

} // namespace qwentts

#endif // QWENTTS_NAPI_H
