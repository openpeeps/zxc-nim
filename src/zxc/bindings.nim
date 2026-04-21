# Bindings to ZXC compression library
# Official Repo: https://github.com/hellobertrand/zxc
# 
# (c) 2026 George Lemon | BSD-3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/zxc-nim

type
  zxc_nim_progress_cb_t* = proc(bytesProcessed: uint64, bytesTotal: uint64, userData: pointer) {.cdecl.}

{.emit: """
#include <stdint.h>
#include <stdio.h>
#include <zxc.h>

typedef void (*zxc_nim_progress_cb_t)(uint64_t, uint64_t, void*);

static inline int64_t zxc_stream_compress_nim(
    FILE* f_in, FILE* f_out, const zxc_compress_opts_t* opts,
    zxc_nim_progress_cb_t cb, void* user_data) {
  zxc_compress_opts_t local;
  const zxc_compress_opts_t* p = opts;
  if (opts) {
    local = *opts;
    local.progress_cb = (zxc_progress_callback_t)cb; // cast once in C
    local.user_data = user_data;
    p = &local;
  }
  return zxc_stream_compress(f_in, f_out, p);
}

static inline int64_t zxc_stream_decompress_nim(
    FILE* f_in, FILE* f_out, const zxc_decompress_opts_t* opts,
    zxc_nim_progress_cb_t cb, void* user_data) {
  zxc_decompress_opts_t local;
  const zxc_decompress_opts_t* p = opts;
  if (opts) {
    local = *opts;
    local.progress_cb = (zxc_progress_callback_t)cb; // cast once in C
    local.user_data = user_data;
    p = &local;
  }
  return zxc_stream_decompress(f_in, f_out, p);
}
""".}

{.push importc, header: "<zxc.h>".}
#
# Constants
#
const
  ZXC_BLOCK_SIZE_MIN_LOG2* = 12
  ZXC_BLOCK_SIZE_MAX_LOG2* = 21
  ZXC_BLOCK_SIZE_DEFAULT* = 256 * 1024
  ZXC_BLOCK_SIZE_MIN* = 1 shl ZXC_BLOCK_SIZE_MIN_LOG2
  ZXC_BLOCK_SIZE_MAX* = 1 shl ZXC_BLOCK_SIZE_MAX_LOG2

  ZXC_OK* = 0.cint
  ZXC_ERROR_MEMORY* = -1.cint
  ZXC_ERROR_DST_TOO_SMALL* = -2.cint
  ZXC_ERROR_SRC_TOO_SMALL* = -3.cint
  ZXC_ERROR_BAD_MAGIC* = -4.cint
  ZXC_ERROR_BAD_VERSION* = -5.cint
  ZXC_ERROR_BAD_HEADER* = -6.cint
  ZXC_ERROR_BAD_CHECKSUM* = -7.cint
  ZXC_ERROR_CORRUPT_DATA* = -8.cint
  ZXC_ERROR_BAD_OFFSET* = -9.cint
  ZXC_ERROR_OVERFLOW* = -10.cint
  ZXC_ERROR_IO* = -11.cint
  ZXC_ERROR_NULL_INPUT* = -12.cint
  ZXC_ERROR_BAD_BLOCK_TYPE* = -13.cint
  ZXC_ERROR_BAD_BLOCK_SIZE* = -14.cint

type 
  zxc_compression_level_t* {.size: sizeof(cuint).} = enum
    ZXC_LEVEL_FASTEST = 1
    ZXC_LEVEL_FAST = 2
    ZXC_LEVEL_DEFAULT = 3
    ZXC_LEVEL_BALANCED = 4
    ZXC_LEVEL_COMPACT = 5

#
# ZXC Buffer API
#
type
  zxc_cctx* {.byCopy, incompleteStruct.} = object
    # Opaque type; actual fields are hidden in C
  zxc_dctx* {.byCopy, incompleteStruct.} = object
    # Opaque type; actual fields are hidden in C

  zxc_cctxPtr* = ptr zxc_cctx
  zxc_dctxPtr* = ptr zxc_dctx

  zxc_progress_callback_t* = proc(bytes_processed: uint64, bytes_total: uint64, user_data: pointer) {.cdecl.}

  zxc_compress_opts_t* {.byCopy.} = object
    n_threads*: cint
    level*: cint
    block_size*: csize_t
    checksum_enabled*: cint
    seekable*: cint
    progress_cb*: zxc_progress_callback_t
    user_data*: pointer

  zxc_decompress_opts_t* {.byCopy.} = object
    n_threads*: cint
    checksum_enabled*: cint
    progress_cb*: zxc_progress_callback_t
    user_data*: pointer

proc zxc_min_level*(): cint
proc zxc_max_level*(): cint
proc zxc_default_level*(): cint
proc zxc_version_string*(): cstring

proc zxc_compress_bound*(input_size: csize_t): uint64
proc zxc_compress*(src: pointer, src_size: csize_t, dst: pointer, dst_capacity: csize_t, opts: ptr zxc_compress_opts_t): int64
proc zxc_decompress*(src: pointer, src_size: csize_t, dst: pointer, dst_capacity: csize_t, opts: ptr zxc_decompress_opts_t): int64
proc zxc_get_decompressed_size*(src: pointer, src_size: csize_t): uint64

proc zxc_compress_block_bound*(input_size: csize_t): uint64
proc zxc_compress_block*(cctx: zxc_cctxPtr, src: pointer, src_size: csize_t, dst: pointer, dst_capacity: csize_t, opts: ptr zxc_compress_opts_t): int64
proc zxc_decompress_block*(dctx: zxc_dctxPtr, src: pointer, src_size: csize_t, dst: pointer, dst_capacity: csize_t, opts: ptr zxc_decompress_opts_t): int64

proc zxc_create_cctx*(opts: ptr zxc_compress_opts_t): zxc_cctxPtr
proc zxc_free_cctx*(cctx: zxc_cctxPtr)
proc zxc_compress_cctx*(cctx: zxc_cctxPtr, src: pointer, src_size: csize_t, dst: pointer, dst_capacity: csize_t, opts: ptr zxc_compress_opts_t): int64
proc zxc_create_dctx*(): zxc_dctxPtr
proc zxc_free_dctx*(dctx: zxc_dctxPtr)
proc zxc_decompress_dctx*(dctx: zxc_dctxPtr, src: pointer, src_size: csize_t, dst: pointer, dst_capacity: csize_t, opts: ptr zxc_decompress_opts_t): int64

#
# ZXC Stream
#
proc zxc_stream_compress*(f_in: ptr File, f_out: ptr File, opts: ptr zxc_compress_opts_t): int64
proc zxc_stream_decompress*(f_in: ptr File, f_out: ptr File, opts: ptr zxc_decompress_opts_t): int64
proc zxc_stream_get_decompressed_size*(f_in: ptr File): int64

proc zxc_error_name*(code: cint): cstring

{.pop.}


proc zxc_stream_compress_nim(f_in: ptr File, f_out: ptr File, opts: ptr zxc_compress_opts_t, cb: zxc_nim_progress_cb_t, user_data: pointer): int64 {.importc, cdecl.}
proc zxc_stream_decompress_nim(f_in: ptr File, f_out: ptr File, opts: ptr zxc_decompress_opts_t, cb: zxc_nim_progress_cb_t, user_data: pointer): int64 {.importc, cdecl.}
