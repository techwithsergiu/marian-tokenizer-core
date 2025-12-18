# Marian Tokenizer Core (C++)

## Overview

This project provides a **standalone C++ implementation of the Marian tokenizer**, statically linked with **SentencePiece**, packaged as both static and shared libraries for reuse across languages and runtimes. It exists to make Marian tokenization portable, dependency-minimal, and embeddable — enabling integration in environments such as **Go**, and serving as a reusable building block for **ONNX-based translation pipelines**.

---

## Scope / Non-goals

**In scope:**

- Providing a **pure C++ Marian tokenizer core**, statically linked with SentencePiece.
- Building **static and shared libraries** suitable for reuse from other languages (e.g. Go).
- Supporting **cross-platform builds** on major platforms via a Makefile-based build system.
- Serving as a **reusable tokenizer component** for downstream systems such as ONNX-based translation pipelines.

**Non-goals / explicitly out of scope:**

- No model training or inference logic (tokenization only).
- No runtime downloads: models, vocabularies, and configs are **not fetched automatically**.
- No CLI tool or end-user application.
- No Python bindings or Python-based tooling.
- No guarantees of API stability across major versions.
- Not a full Marian runtime or replacement for Marian NMT.

All required third-party code (e.g. SentencePiece, JSON library) is vendored or included as submodules within the repository; users are not expected to download external dependencies at build time.

---

## What it uses

- **SentencePiece (C++ core)** for subword tokenization, built from the included git submodule and linked into the produced libraries
- **JSON for Modern C++ (nlohmann/json)** as a vendored header for parsing Marian tokenizer config/vocab metadata
- **Makefile-based build** plus a build script for SentencePiece (`scripts/build_sentencepiece.sh`) to produce reproducible outputs under `deps/` and `build/`
- **A C ABI surface** (`src/marian_core.h`) designed to be callable from other languages/runtimes

---

## Capabilities / Features

- Builds a reusable tokenizer library as both **shared** (`.so` / `.dylib` / `.dll`) and **static** (`.a`) artifacts
- Creates a tokenizer instance from a Marian model directory containing `config.json`, `vocab.json`, `source.spm`, and `target.spm`
- Encodes UTF-8 text into Marian token IDs (single input) with optional EOS handling
- Batch-encodes multiple UTF-8 inputs into a padded `[batch_size * max_len]` buffer and returns per-row sequence lengths
- Builds **attention masks** from sequence lengths (0/1 mask, row-major)
- Decodes Marian token IDs back into UTF-8 text with optional special-token stripping
- Exposes `config.json` back to callers as raw JSON bytes and provides explicit buffer ownership APIs (`marian_tok_free_buffer`)

---

## Build & Setup

### Prerequisites

- A standard C/C++ toolchain (compiler + `make`) available on your system.
- Git submodules initialized (SentencePiece is included as a submodule).

### Setup

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/techwithsergiu/marian-tokenizer-core.git
cd marian-tokenizer-core
```

### Build

1. Build SentencePiece into `./deps`:

   ```bash
   make deps
   ```

   This runs `scripts/build_sentencepiece.sh` and produces headers and libraries under:

   ```bash
   deps/sentencepiece/include/
   deps/sentencepiece/<OS_ARCH>/lib/
   deps/sentencepiece/<OS_ARCH>/lib/static/
   ```
2. Build Marian Tokenizer Core:

   Build everything:

   ```bash
   make all
   ```

   Or build individual artifacts:

   ```bash
   make static     # libmarian_core.a
   make shared     # libmarian_core.so / dylib / dll
   ```

   Outputs are written under:

   ```bash
   build/include/
   build/src/
   build/<OS_ARCH>/lib/
   build/<OS_ARCH>/lib/static/
   ```

### Common Make targets

```bash
make help
make print-vars
make clean
```

Notes:

- You can pass `TARGET_OS=linux|darwin|windows` and `TARGET_ARCH=amd64|arm64` to control the build output target.

---

## Usage

### Minimal model directory

The tokenizer expects a Marian-compatible model directory with the following files:

```text
models/opus-mt-ru-en/
├── config.json
├── source.spm
├── target.spm
└── vocab.json
```

These files are **not included** in the repository and must be provided by the user.

### Minimal C usage example

```c
#include "marian_core.h"
#include <stdio.h>

int main() {
    // Create tokenizer from model directory
    marian_tok_t tok = marian_tok_new("models/opus-mt-ru-en");
    if (!tok) {
        printf("Failed to create tokenizer\n");
        return 1;
    }

    // Encode text
    const char* text = "Hello world";
    long long ids[64];

    int n = marian_tok_encode(
        tok,
        text,
        ids,
        64,     // max_ids
        1       // add_eos
    );

    if (n < 0) {
        printf("Encode failed\n");
        marian_tok_free(tok);
        return 1;
    }

    printf("Encoded %d tokens:\n", n);
    for (int i = 0; i < n; i++) {
        printf("%lld ", ids[i]);
    }
    printf("\n");

    // Decode back
    char out[256];
    int out_len = marian_tok_decode(
        tok,
        ids,
        n,
        1,      // skip_special
        out,
        sizeof(out)
    );

    if (out_len >= 0) {
        out[out_len] = '\0';
        printf("Decoded text: %s\n", out);
    }

    // Cleanup
    marian_tok_free(tok);
    return 0;
}

```

Notes:

- All strings are UTF-8.
- Output buffers are owned by the caller unless explicitly documented otherwise.
- The API is designed to be callable from other languages via FFI.

---

## Public API

The library exposes a **C-compatible ABI** defined in `src/marian_core.h`, designed for safe use from C, C++, and foreign-function interfaces (Go, Java, Node.js, Android NDK).

### Types

- **`marian_tok_t`**
  Opaque handle representing a tokenizer instance. Internally owns:
  - SentencePiece processors (source / target)
  - Vocabulary mappings
  - Parsed Marian configuration

---

### Lifecycle

```c
marian_tok_t marian_tok_new(const char* model_dir);
void marian_tok_free(marian_tok_t handle);
```

- `marian_tok_new` creates a tokenizer from a Marian model directory.
- `marian_tok_free` releases all internal resources.
- The model directory must contain:

  - `config.json`
  - `vocab.json`
  - `source.spm`
  - `target.spm`

### Encoding

```c
int marian_tok_encode(
    marian_tok_t handle,
    const char* text,
    long long* out_ids,
    int max_ids,
    int add_eos
);
```

- Encodes UTF-8 text into Marian token IDs.
- `out_ids` must be preallocated by the caller.
- `add_eos`: `0` or `1`.
- Returns:
  - `>= 0` → number of token IDs written
  - `< 0`  → error code

---

### Batch encoding

```c
int marian_tok_encode_batch(
    marian_tok_t handle,
    const char** texts,
    int batch_size,
    int max_len,
    long long* out_ids,
    int* out_seq_lens,
    int add_eos
);
```

- Encodes multiple UTF-8 strings at once.
- Output layout:
  - `out_ids`: `[batch_size * max_len]`, row-major
  - `out_seq_lens`: actual length per row
- Returns:
  - `>= 0` → maximum sequence length in the batch
  - `< 0`  → error code

---

### Attention mask helper

```c
int marian_tok_build_attention_mask(
    const int* seq_lens,
    int batch_size,
    int max_len,
    int* out_mask
);
```

- Builds a 0/1 attention mask from sequence lengths.
- Output layout: `[batch_size * max_len]`, row-major.
- Returns `0` on success, `< 0` on error

---

### Decoding

```c
int marian_tok_decode(
    marian_tok_t handle,
    const long long* ids,
    int len,
    int skip_special,
    char* out_text,
    int max_text_len
);
```

- Decodes token IDs back into UTF-8 text.
- `skip_special`: remove special tokens if set to `1`.
- Returns:
  - `>= 0` → decoded string length (without `\0`)
  - `< 0`  → error code

---

### Configuration access

```c
const char* marian_tok_get_config_json(
    marian_tok_t handle,
    size_t* out_len
);
```

- Returns raw `config.json` bytes.
- The returned buffer must be released using `marian_tok_free_buffer`.

```c
void marian_tok_free_buffer(void* p);
```

---

### Ownership & safety notes

- All tokenizer instances are **explicitly owned** by the caller.
- Output buffers are caller-allocated unless stated otherwise.
- The API does not perform internal synchronization; thread-safety is the responsibility of the caller.

---

## Architecture

### High-level flow

1. **Initialization**

   - The caller creates a tokenizer instance by pointing to a Marian model directory.
   - `config.json`, `vocab.json`, `source.spm`, and `target.spm` are loaded eagerly.
   - Two independent **SentencePiece processors** are initialized (source / target).
   - Vocabulary mappings (`token ↔ id`) and special-token sets are constructed in memory.
2. **Encoding**

   - Input UTF-8 text is passed to SentencePiece for subword segmentation.
   - Tokens are mapped to Marian vocabulary IDs.
   - Optional EOS handling is applied.
   - For batch mode, results are written into a fixed-stride, row-major buffer with per-row sequence lengths.
3. **Post-processing helpers**

   - Attention masks are derived purely from sequence lengths, independent of token values.
   - This allows direct reuse in transformer-based inference pipelines (e.g. ONNX Runtime).
4. **Decoding**

   - Token IDs are mapped back to string tokens.
   - Special tokens may be filtered.
   - SentencePiece performs detokenization back to UTF-8 text.

---

### Internal components

- **MarianCore**
  - Owns SentencePiece processors, vocabulary tables, special-token metadata, and parsed config.
- **MarianCoreConfig**
  - Holds tokenizer-relevant values extracted from `config.json` (IDs, lengths, limits).
- **C ABI layer**
  - Thin, allocation-explicit wrapper around the internal C++ structures, designed for FFI safety.

---

### Design notes

- **No dynamic downloads**
  All required assets are provided by the caller; the library performs no network access.
- **Static-link friendly**
  SentencePiece is built as a static library and can be fully embedded into a single binary.
- **Language-agnostic boundary**
  The public API avoids STL types and exceptions, enabling predictable cross-language bindings.
- **Deterministic memory ownership**
  All allocations crossing the API boundary have explicit free functions.

---

### Performance & integration notes

- Tokenization cost is dominated by SentencePiece; no extra abstraction layers are introduced.
- Batch APIs are designed to minimize per-call overhead and match tensor-friendly layouts.
- The output shapes are intentionally aligned with transformer inference runtimes such as ONNX Runtime.

---

## Project layout

```text
marian-tokenizer-core/
├── build/                          # Generated artifacts (after build)
│   ├── include/                    # Exported public headers
│   ├── src/                        # Generated / copied sources
│   └── <OS_ARCH>/lib/              # Shared libraries (.so / .dylib / .dll)
│       └── static/                 # Static libraries (.a)
├── deps/
│   └── sentencepiece/              # Built SentencePiece artifacts
│       ├── include/                # SentencePiece headers
│       └── <OS_ARCH>/lib/           # SentencePiece libraries
│           └── static/
├── src/
│   ├── marian_core.h               # Public C ABI header
│   └── marian_core.cc              # C++ tokenizer implementation
├── third_party/
│   ├── nlohmann/json.hpp           # Vendored header-only JSON library
│   └── sentencepiece/              # SentencePiece git submodule (source)
├── scripts/
│   └── build_sentencepiece.sh      # Builds SentencePiece into ./deps
├── Makefile                        # Build orchestration and targets
├── .gitmodules                     # Submodule definitions
├── .gitignore
├── LICENSE
└── README.md
```

Notes:

- The `build/` and `deps/` directories are **generated** and not meant for manual editing.
- The repository  **does not contain any Marian or Opus-MT models** .
- Model files (`config.json`, `vocab.json`, `source.spm`, `target.spm`) must be supplied externally by the user and are intentionally excluded from version control.

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

This project relies on several third-party components, all using permissive
licenses compatible with Apache License 2.0:

- **SentencePiece (C++ core)** — Apache License 2.0 (© Google)  
  [github.com/google/sentencepiece](https://github.com/google/sentencepiece)

- **JSON for Modern C++** — MIT License (© Niels Lohmann)  
  [github.com/nlohmann/json](https://github.com/nlohmann/json)

All listed dependencies are compatible with Apache 2.0 and suitable for
commercial and open-source use.

No Marian / Opus-MT models, vocabularies, or tokenizer assets are distributed
with this repository.

---
