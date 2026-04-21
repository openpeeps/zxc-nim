<p align="center">
  Bindings to the <a href="https://github.com/hellobertrand/zxc">ZXC compression library</a><br>
  A LZ77-based compressor optimized for high decompression speed
</p>

<p align="center">
  <code>nimble install zxc</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/zxc-nim/">API reference</a><br>
  <img src="https://github.com/openpeeps/zxc-nim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/zxc-nim/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- Write-Once, Read-Many compression
- Optimized for **Game Assets**, **Firmware** & **App Bundles**
- High decompression speed
- **Stream API** for compressing/decompressing large data
- Multi-threaded Streaming API for even faster performance
- Optional **Checksum Validation**
- Level-based compression (Fastest, Fast, Default, Balanced and Compact)
- Reusable contexts for high-frequency call sites
- **Seekable archives** (Optional seek table for O(1) random access)

## Installation
Use your favorite package manager to install the ZXC library, or [build it from source](https://github.com/hellobertrand/zxc#option-5-building-from-source).

## Examples

Compressing and decompressing strings with mutable buffers
```nim
let original = "The quick brown fox jumps over the lazy dog 🦊"
var compressed: CompZscBytes # seq[byte]
compressBytes(original, compressed, ZXC_LEVEL_DEFAULT, false)

var decompressed: DecompZscBytes # seq[byte]
decompressBytes(compressed, decompressed, false)
assert decompressed.bytesToString == original
```

Use ZXC's streaming API for large data or when you want to enjoy multi-threaded performance
```nim
let testFile = "test_zxc_input.txt"
let compressedFile = "test_zxc_input.txt.zxc"
let decompressedFile = "test_zxc_input_out.txt"
let content = "ZXC file streaming test!\nLine 2.\nLine 3."

compressFile(testFile, compressedFile, level = ZXC_LEVEL_DEFAULT, checksumEnabled = true)
decompressFile(compressedFile, decompressedFile, checksumEnabled = true)

assert readFile(decompressedFile) == content
```

Check more examples in the [tests directory](https://github.com/openpeeps/zxc-nim/blob/main/tests/test1.nim)

_todo: example with reusable contexts and seekable archives_

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/zxc-nim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/zxc-nim/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)

### 🎩 License
BSD-3-Clause license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright OpenPeeps & Contributors &mdash; All rights reserved.
