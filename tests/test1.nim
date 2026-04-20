{.passC:"-I/usr/local/include", passL:"-L/usr/local/lib -lzxc".}

import std/[os, unittest]
import ../src/zxc

suite "ZXC High-Level API":

  test "compress and decompress string (default level)":
    let original = "The quick brown fox jumps over the lazy dog 🦊"
    var compressed: CompZscBytes
    compress(original, compressed)
    var decompressed: DecompZscBytes
    decompress(compressed, decompressed)
    check $decompressed == original

  test "compress and decompress string (explicit level, checksum)":
    let original = "Nim is fast and expressive!"
    var compressed: CompZscBytes
    compress(original, compressed, level = ZXC_LEVEL_COMPACT, checksumEnabled = true)
    var decompressed: DecompZscBytes
    decompress(compressed, decompressed, checksumEnabled = true)
    check bytesToString(decompressed) == original

  test "compressString and decompressString convenience":
    let original = "Hello, ZXC!"
    let compressed = compressString(original)
    let decompressed = decompressString(compressed)
    check decompressed == original

  test "compressBytes and decompressBytes (raw bytes)":
    let original = @[byte 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    var compressed: CompZscBytes
    compressBytes(original, compressed, ZXC_LEVEL_FAST, true)
    var decompressed: DecompZscBytes
    decompressBytes(compressed, decompressed, true)
    check decompressed == original

  test "file roundtrip (stream API)":
    let testFile = "test_zxc_input.txt"
    let compressedFile = "test_zxc_input.txt.zxc"
    let decompressedFile = "test_zxc_input_out.txt"
    let content = "ZXC file streaming test!\nLine 2.\nLine 3."
    writeFile(testFile, content)
    compressFile(testFile, compressedFile, level = ZXC_LEVEL_DEFAULT, checksumEnabled = true)
    decompressFile(compressedFile, decompressedFile, checksumEnabled = true)
    check readFile(decompressedFile) == content
    removeFile(testFile)
    removeFile(compressedFile)
    removeFile(decompressedFile)

  test "decompressString fails on bad input":
    expect ZxcError:
      discard decompressString(@[byte 0xFF, 0xFF, 0xFF])

  test "compress and decompress empty string":
    let original = ""
    try:
      let compressed = compressString(original)
      let decompressed = decompressString(compressed)
      check decompressed == original
    except ZxcError as e:
      check e.code == ZXC_ERROR_NULL_INPUT

  test "compress and decompress empty bytes":
    let original: seq[byte] = @[]
    var compressed: CompZscBytes
    try:
      compressBytes(original, compressed, ZXC_LEVEL_DEFAULT, false)
      var decompressed: DecompZscBytes
      decompressBytes(compressed, decompressed, false)
      check decompressed == original
    except ZxcError as e:
      check e.code == ZXC_ERROR_NULL_INPUT