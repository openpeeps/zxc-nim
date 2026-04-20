# Bindings to ZXC compression library
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/zxc-nim

import std/[os, memfiles, strformat]
import ./zxc/bindings
export bindings

type
  ZxcProgressCallback* = zxc_progress_callback_t
  ZxcCompressionLevel* = zxc_compression_level_t
  CompZscBytes* = seq[byte]
  DecompZscBytes* = seq[byte]
  ZxcError* = object of CatchableError
    code*: cint

proc raiseZxc*(code: int64; msg: string) {.noreturn.} =
  ## Raises a ZxcError with the given code and message
  var e = newException(ZxcError, fmt"{msg} (zxc code: {code})")
  e.code = code.cint
  raise e

proc bytesToString*(b: openArray[byte]): string =
  ## Converts a byte sequence to a string (UTF-8 decoding)
  if b.len == 0:
    return ""
  result = newString(b.len)
  copyMem(addr result[0], unsafeAddr b[0], b.len)

proc stringToBytes*(s: string): seq[byte] =
  ## Converts a string to a byte sequence (UTF-8 encoding)
  if s.len == 0:
    return @[]
  result = newSeq[byte](s.len)
  copyMem(addr result[0], unsafeAddr s[0], s.len)

proc compressBytes*(input: openArray[byte], output: var CompZscBytes,
          level: ZxcCompressionLevel, checksumEnabled: bool) =
  ## Compresses the given bytes to the mutable output sequence.
  let inSize = input.len.csize_t
  let bound = zxc_compress_bound(inSize)
  if bound == 0'u64 and input.len > 0:
    raiseZxc(-1, "zxc_compress_bound failed")

  output = newSeq[byte](bound.int)

  var opts: zxc_compress_opts_t
  opts.level = level.cint
  opts.checksum_enabled = (if checksumEnabled: 1 else: 0)

  let srcPtr = if input.len == 0: nil else: cast[pointer](unsafeAddr input[0])
  let dstPtr = if output.len == 0: nil else: cast[pointer](addr output[0])

  let written = zxc_compress(srcPtr, inSize, dstPtr, bound.csize_t, addr opts)
  if written < 0:
    raiseZxc(written, "zxc_compress failed")

  output.setLen(written.int)

proc decompressBytes*(compressed: openArray[byte], output: var DecompZscBytes, checksumEnabled: bool) =
  ## Decompresses the given compressed bytes. The output sequence is resized
  ## to fit the decompressed data
  let srcSize = compressed.len.csize_t
  let outSize = zxc_get_decompressed_size(
    (
      if compressed.len == 0: nil
      else: cast[pointer](unsafeAddr compressed[0])
    ),
    srcSize
  )

  if outSize == 0'u64 and compressed.len > 0:
    raiseZxc(-1, "zxc_get_decompressed_size failed or invalid input")

  output = newSeq[byte](outSize.int)

  var opts: zxc_decompress_opts_t
  opts.checksum_enabled = (if checksumEnabled: 1 else: 0)

  let srcPtr = if compressed.len == 0: nil else: cast[pointer](unsafeAddr compressed[0])
  let dstPtr = if output.len == 0: nil else: cast[pointer](addr output[0])
  let written = zxc_decompress(srcPtr, srcSize, dstPtr, outSize.csize_t, addr opts)
  if written < 0:
    # decompression failed, remove any partially written output
    raiseZxc(written, "zxc_decompress failed")
  
  # resize output to actual decompressed size
  output.setLen(written.int)

#
# Compress and decompress strings
#
proc compress*(s: string, output: var CompZscBytes,
                level: ZxcCompressionLevel = ZXC_LEVEL_DEFAULT,
                checksumEnabled = false) =
  ## Compresses the given string and returns the compressed bytes
  compressBytes(stringToBytes(s), output, level, checksumEnabled)

proc decompress*(compressed: openArray[byte], output: var DecompZscBytes,
                checksumEnabled: bool = false) =
  ## Decompresses the given compressed bytes and returns the result
  decompressBytes(compressed, output, checksumEnabled)

proc `$`*(decompZscBytes: DecompZscBytes): string =
  ## String representation of decompressed bytes for debugging
  bytesToString(decompZscBytes)

proc compressString*(s: string, level: ZxcCompressionLevel = ZXC_LEVEL_DEFAULT,
                checksumEnabled = false): CompZscBytes =
  ## Compresses the given string and returns the compressed bytes
  var output: CompZscBytes
  compress(s, output, level, checksumEnabled)
  result = output

proc decompressString*(compressed: openArray[byte], checksumEnabled: bool = false): string =
  ## Decompresses the given compressed bytes and returns the result as a string
  var output: DecompZscBytes
  decompress(compressed, output, checksumEnabled)
  bytesToString(output)

#
# Compress and decompress streams (files)
#
proc asCFile(f: File): ptr File {.inline.} =
  cast[ptr File](f)

proc compressStream*(fIn, fOut: File, level: ZxcCompressionLevel = ZXC_LEVEL_DEFAULT,
            nThreads: cint = 0, blockSize: csize_t = 0, checksumEnabled = true,
            seekable = false, progressCb: ZxcProgressCallback = nil, userData: pointer = nil
  ): int64 =
  ## High-level streaming compression on already-open files.
  var opts: zxc_compress_opts_t
  opts.n_threads = nThreads
  opts.level = level.cint
  opts.block_size = blockSize
  opts.checksum_enabled = (if checksumEnabled: 1 else: 0)
  opts.seekable = (if seekable: 1 else: 0)

  result = zxc_stream_compress(asCFile(fIn), asCFile(fOut), addr opts)

  if result < 0:
    raiseZxc(result, "zxc_stream_compress failed")

proc decompressStream*(fIn, fOut: File, nThreads: cint = 0,  checksumEnabled = true,
                progressCb: ZxcProgressCallback = nil, userData: pointer = nil): int64 =
  ## High-level streaming decompression on already-open files 
  ## with optional multithreading and progress callback.
  var opts: zxc_decompress_opts_t
  opts.n_threads = nThreads
  opts.checksum_enabled = (if checksumEnabled: 1 else: 0)

  result = zxc_stream_decompress(asCFile(fIn), asCFile(fOut), addr opts)

  if result < 0:
    raiseZxc(result, "zxc_stream_decompress failed")

#
# Compress and decompress files
#
proc compressFile*(inputPath, outputPath: string,
          level: ZxcCompressionLevel = ZXC_LEVEL_DEFAULT,
          checksumEnabled = false) =
  ## Fast file compression via ZXC streaming API with optional checksum
  if not fileExists(inputPath):
    raise newException(ZxcError, "Input file does not exist: " & inputPath)
  if fileExists(outputPath):
    raise newException(ZxcError, "Output file already exists: " & outputPath)
  var fIn: File
  if not open(fIn, inputPath, fmRead):
    raise newException(ZxcError, "Failed to open input file: " & inputPath)
  defer: close(fIn)

  var fOut: File
  if not open(fOut, outputPath, fmWrite):
    raise newException(ZxcError, "Failed to open output file: " & outputPath)
  defer: close(fOut)

  discard compressStream(fIn, fOut, level, checksumEnabled = checksumEnabled)

proc decompressFile*(inputPath, outputPath: string, checksumEnabled = false) =
  ## Fast file decompression via ZXC streaming API with optional checksum verification.
  var fIn: File
  if not open(fIn, inputPath, fmRead):
    raise newException(ZxcError, "Failed to open input file: " & inputPath)
  defer: close(fIn)

  var fOut: File
  if not open(fOut, outputPath, fmWrite):
    raise newException(ZxcError, "Failed to open output file: " & outputPath)
  defer: close(fOut)

  discard decompressStream(fIn, fOut, checksumEnabled = checksumEnabled)

when isMainModule:
  {.passC:"-I/usr/local/include", passL:"-L/usr/local/lib -lzxc".}
  
  block:
    var compBytes: CompZscBytes
    let s = """
Features
    Fast decompression: Optimized for read-heavy workloads
    5 compression levels: Trade off speed vs ratio
    Optional checksums: Disabled by default for maximum performance, enable for data integrity
    File streaming: Multi-threaded compression/decompression for large files
    Zero-allocation API: compress_to and decompress_to for buffer reuse
    Pure Rust API: Safe, idiomatic interface over the C library
"""
    s.compress(compBytes, level = ZXC_LEVEL_COMPACT, checksumEnabled = true)
    
    var decompBytes: DecompZscBytes
    decompress(compBytes, decompBytes)

    echo compBytes
    echo "in:  ", s.len
    echo "cmp: ", compBytes.len
    echo "out: ", decompBytes.len
    echo "decompressed matches original: ", bytesToString(decompBytes) == s
  
  # block:
  #   compressFile("tripadvisor_european_restaurants.csv",
  #     "tripadvisor_european_restaurants.csv.zxc",
  #     level = ZXC_LEVEL_FASTEST, checksumEnabled = false)
  #   decompressFile("tripadvisor_european_restaurants.csv.zxc", "tripadvisor_european_restaurants_decompressed_2.csv")