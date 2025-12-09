# Marian Tokenizer Core (C++)

A lightweight, standalone **C++ tokenizer engine** for Marian-based NMT models — portable, dependency‑minimal, and ready to embed into **Go, Java, Node.js, Android NDK**, or any other runtime.

This repository contains **only the tokenizer core**, extracted and cleaned for reuse.

---

## Overview

- Pure C++ implementation (no Python, no virtualenv).
- Uses **SentencePiece (C++)** internally.
- Ships as both **static (`.a`)** and **shared (`.so` / `.dylib` / `.dll`)** libraries.
- Clean, minimal API in `src/marian_core.h`.
- Fully scriptable build system (Makefile + build scripts).
- Suitable for:
  - cross‑platform builds,
  - embedding into mobile/CLI tools,
  - multi-language bindings.

---

## Repository Structure

```bash
.
├── build                           # libmarian_core.a / .so / headers / src
│   ├── include/
│   ├── src/
│   └── '$OS_ARCH'/lib/
│       └── static/
├── deps
│   └── sentencepiece               # libsentencepiece.a / .so / headers
│       ├── include/
│       └── '$OS_ARCH'/lib/
│           └── static/
├── src
│   ├── json.hpp
│   ├── marian_core.h               # Public API
│   └── marian_core.cc              # C++ Marian tokenizer implementation
├── third_party
│   └── sentencepiece               # git submodule (Google SentencePiece)
├── scripts
│   └── build_sentencepiece.sh      # Builds SentencePiece into ./deps
├── Makefile
└── README.md
```

---

## Quick Start

### 1. Clone (with submodules)

```bash
git clone --recurse-submodules https://github.com/techwithsergiu/marian-tokenizer-core.git
cd marian-tokenizer-core
```

---

## Build Instructions

### Step 1 — Build SentencePiece

```bash
make deps
```

This runs `scripts/build_sentencepiece.sh`  
and produces:

```bash
deps/sentencepiece/include/
deps/sentencepiece/<OS_ARCH>/lib/
deps/sentencepiece/<OS_ARCH>/lib/static/
```

### Step 2 — Build Marian Core

Build everything:

```bash
make all
```

Or individually:

```bash
make static     # libmarian_core.a
make shared     # libmarian_core.so / dylib / dll
make clean
```

Output appears under:

```bash
build/include/
build/src/
build/<OS_ARCH>/lib/
build/<OS_ARCH>/lib/static/
```

---

## Linking Marian Core From Other Projects

### Using the shared library (`.so`, `.dylib`, `.dll`)

```bash
-Lbuild/<OS_ARCH>/lib -lmarian_core -lsentencepiece
```

Make sure to include:

```bash
build/include/
deps/sentencepiece/include/
```

### Using the static library (`.a`)

```bash
libmarian_core.a
libsentencepiece.a
```

Recommended for embedded, mobile, or single‑binary deployment.

---

## API Summary (C ABI)

All public functions are declared in:

```c
#include "marian_core.h"
```

### Handles

```c
typedef void* marian_tok_t;
```

- `marian_tok_t` — opaque handle to an internal tokenizer instance.

### Lifecycle

```c
MARIAN_API marian_tok_t marian_tok_new(const char* model_dir);
MARIAN_API void         marian_tok_free(marian_tok_t handle);
```

- `model_dir` must contain: `config.json`, `vocab.json`, `source.spm`, `target.spm`.

### Model metadata

```c
MARIAN_API long long marian_tok_get_pad_id(marian_tok_t handle);
MARIAN_API long long marian_tok_get_model_max_length(marian_tok_t handle);
```

### Encoding (single string)

```c
MARIAN_API int marian_tok_encode(
    marian_tok_t handle,
    const char*  text,
    long long*   out_ids,
    int          max_ids,
    int          add_eos  // 0 or 1
);
```

- Returns `>= 0` — number of token IDs written to `out_ids`.
- Returns `< 0` — error code.

### Encoding (batch)

```c
MARIAN_API int marian_tok_encode_batch(
    marian_tok_t  handle,
    const char**  texts,
    int           batch_size,
    int           max_len,
    long long*    out_ids,      // [batch_size * max_len]
    int*          out_seq_lens, // [batch_size]
    int           add_eos       // 0 or 1
);
```

- Returns `>= 0` — maximum sequence length across the batch.
- Returns `< 0` — error code.

### Attention masks

```c
MARIAN_API int marian_tok_build_attention_mask(
    const int* seq_lens, // [batch_size]
    int        batch_size,
    int        max_len,
    int*       out_mask  // [batch_size * max_len], 0/1
);
```

- Returns `0` on success, `< 0` on error.

### Decoding

```c
MARIAN_API int marian_tok_decode(
    marian_tok_t    handle,
    const long long*ids,
    int             len,
    int             skip_special, // 0 or 1
    char*           out_text,
    int             max_text_len
);
```

- Returns `>= 0` — length of decoded UTF‑8 text (without `\0`).
- Returns `< 0` — error code.

---

## License

This project is licensed under the **Apache License 2.0**.

You are free to use, modify, and distribute this software in both open-source
and commercial applications, as long as you comply with the terms of the
Apache 2.0 License.

Full license text:  
[LICENSE](LICENSE)

---

## Third-party Licenses

This project relies on several third-party libraries, all using permissive
licenses fully compatible with Apache 2.0:

- **SentencePiece (C++ core)** — Apache License 2.0 (© Google)  
  [github.com/google/sentencepiece](https://github.com/google/sentencepiece)
- **JSON for Modern C++** — MIT License (© Niels Lohmann)  
  [github.com/nlohmann/json](https://github.com/nlohmann/json)

This makes the entire project fully Apache-compatible and safe for commercial use.

---
