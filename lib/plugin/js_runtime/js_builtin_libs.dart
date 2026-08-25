import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
// JavascriptCoreRuntime 没有被 flutter_js.dart 顶层导出，需要单独引入。
// 它只在 iOS / macOS 分支被实例化；其余平台只 import 不执行，跨平台编译安全。
import 'package:flutter_js/javascriptcore/jscore_runtime.dart';

/// JS 沙箱里预置的内置工具函数（纯 JS 实现，随 App 打包、不联网）。
///
/// 为什么不用"JS → Dart 桥接"：
/// flutter_js 0.8.7 的 `setupBridge` 回调签名是 `void Function(dynamic)`，
/// 回调的返回值会被丢弃（JS 侧 `sendMessage` 拿不到结果），无法实现
/// "JS 同步调用 Dart 算 md5"这套机制。所以加密能力直接以**纯 JS** 形式
/// 注入沙箱——MD5 / SHA1 / SHA256 / HMAC / Base64 都是标准算法，
/// 用广为人知的实现移植即可，行为跨平台一致（QuickJS / JSCore 通用），
/// 也和插件开发文档第 5.1 节承诺的 `CryptoJS` 全局对象保持一致。
///
/// 可用 API（插件作者直接调用，无需 require/import）：
///   md5(str) / sha1(str) / sha256(str)
///   hmacSha256(str, key) / hmacMd5(str, key)
///   base64Encode(str) / base64Decode(str)
///   urlEncode(str) / urlDecode(str)
///   CryptoJS.MD5(str).toString() 等（crypto-js 风格）
const String jsBuiltins = r'''
// ===================== 内部工具：UTF-8 编解码 =====================

// 把 JS 字符串编码成 UTF-8 字节数组（处理中文、emoji 等）
function _utf8Encode(str) {
  var bytes = [];
  for (var i = 0; i < str.length; i++) {
    var code = str.charCodeAt(i);
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6), 0x80 | (code & 63));
    } else if (code >= 0xd800 && code <= 0xdbff && i + 1 < str.length) {
      // 高位代理 + 低位代理 -> 4 字节（补充平面字符，如 emoji）
      var next = str.charCodeAt(i + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        var cp = 0x10000 + ((code - 0xd800) << 10) + (next - 0xdc00);
        bytes.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
        i++; // 跳过低位代理
        continue;
      }
      bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63));
    } else if (code < 0x10000) {
      bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63));
    } else {
      bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 63), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63));
    }
  }
  return new Uint8Array(bytes);
}

// 把 UTF-8 字节数组解码回 JS 字符串
function _utf8Decode(bytes) {
  var out = '';
  var i = 0;
  while (i < bytes.length) {
    var b = bytes[i];
    if (b < 0x80) {
      out += String.fromCharCode(b);
      i++;
    } else if ((b & 0xe0) === 0xc0) {
      out += String.fromCharCode(((b & 0x1f) << 6) | (bytes[i + 1] & 0x3f));
      i += 2;
    } else if ((b & 0xf0) === 0xe0) {
      out += String.fromCharCode(((b & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f));
      i += 3;
    } else {
      var cp = ((b & 0x07) << 18) | ((bytes[i + 1] & 0x3f) << 12) | ((bytes[i + 2] & 0x3f) << 6) | (bytes[i + 3] & 0x3f);
      // 还原成代理对，交给 String.fromCharCode 输出
      cp -= 0x10000;
      out += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
      i += 4;
    }
  }
  return out;
}

// 字节 -> 两位小写十六进制
function _h2(x) {
  var s = x.toString(16);
  return s.length < 2 ? '0' + s : s;
}

// ===================== MD5（RFC 1321）=====================

var _md5K = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
];
var _md5S = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
];

function _md5Rotate(x, n) {
  return ((x << n) | (x >>> (32 - n))) >>> 0;
}

// 输入字节数组（Uint8Array），输出 16 字节摘要（Uint8Array）
function _md5Bytes(bytes) {
  var bitLen = bytes.length * 8;
  var hi = Math.floor(bitLen / 4294967296);
  var lo = bitLen >>> 0;
  var paddedLen = (((bytes.length + 8) >> 6) << 6) + 64;
  var m = new Uint8Array(paddedLen);
  m.set(bytes);
  m[bytes.length] = 0x80;
  // 尾部 8 字节：原始 bit 长度，小端序（低 4 字节在前）
  m[paddedLen - 8] = lo & 0xff;
  m[paddedLen - 7] = (lo >>> 8) & 0xff;
  m[paddedLen - 6] = (lo >>> 16) & 0xff;
  m[paddedLen - 5] = (lo >>> 24) & 0xff;
  m[paddedLen - 4] = hi & 0xff;
  m[paddedLen - 3] = (hi >>> 8) & 0xff;
  m[paddedLen - 2] = (hi >>> 16) & 0xff;
  m[paddedLen - 1] = (hi >>> 24) & 0xff;

  // 小端读成 32 位字
  var words = new Uint32Array(paddedLen / 4);
  for (var i = 0; i < paddedLen; i += 4) {
    words[i >> 2] = m[i] | (m[i + 1] << 8) | (m[i + 2] << 16) | (m[i + 3] << 24);
  }

  var a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
  var A = a0, B = b0, C = c0, D = d0;

  for (var i = 0; i < words.length; i += 16) {
    var AA = A, BB = B, CC = C, DD = D;
    for (var j = 0; j < 64; j++) {
      var F, g;
      if (j < 16) { F = (B & C) | (~B & D); g = j; }
      else if (j < 32) { F = (D & B) | (~D & C); g = (5 * j + 1) & 15; }
      else if (j < 48) { F = B ^ C ^ D; g = (3 * j + 5) & 15; }
      else { F = C ^ (B | ~D); g = (7 * j) & 15; }
      F = (F + A + _md5K[j] + words[i + g]) >>> 0;
      A = D; D = C; C = B;
      B = (B + _md5Rotate(F, _md5S[j])) >>> 0;
    }
    A = (A + AA) >>> 0; B = (B + BB) >>> 0; C = (C + CC) >>> 0; D = (D + DD) >>> 0;
  }

  var out = new Uint8Array(16);
  var v = [A, B, C, D];
  for (var i = 0; i < 4; i++) {
    out[i * 4] = v[i] & 0xff;
    out[i * 4 + 1] = (v[i] >>> 8) & 0xff;
    out[i * 4 + 2] = (v[i] >>> 16) & 0xff;
    out[i * 4 + 3] = (v[i] >>> 24) & 0xff;
  }
  return out;
}

// ===================== SHA1（FIPS 180-1）=====================

function _sha1Rotate(x, n) {
  return ((x << n) | (x >>> (32 - n))) >>> 0;
}

// 输入字节数组，输出 20 字节摘要
function _sha1Bytes(bytes) {
  var bitLen = bytes.length * 8;
  var hi = Math.floor(bitLen / 4294967296);
  var lo = bitLen >>> 0;
  var paddedLen = (((bytes.length + 8) >> 6) << 6) + 64;
  var m = new Uint8Array(paddedLen);
  m.set(bytes);
  m[bytes.length] = 0x80;
  // 大端序写入 64 位长度
  m[paddedLen - 8] = (hi >>> 24) & 0xff;
  m[paddedLen - 7] = (hi >>> 16) & 0xff;
  m[paddedLen - 6] = (hi >>> 8) & 0xff;
  m[paddedLen - 5] = hi & 0xff;
  m[paddedLen - 4] = (lo >>> 24) & 0xff;
  m[paddedLen - 3] = (lo >>> 16) & 0xff;
  m[paddedLen - 2] = (lo >>> 8) & 0xff;
  m[paddedLen - 1] = lo & 0xff;

  var h0 = 0x67452301, h1 = 0xEFCDAB89, h2 = 0x98BADCFE, h3 = 0x10325476, h4 = 0xC3D2E1F0;

  for (var offset = 0; offset < paddedLen; offset += 64) {
    var w = new Uint32Array(80);
    for (var i = 0; i < 16; i++) {
      var p = offset + i * 4;
      w[i] = (m[p] << 24) | (m[p + 1] << 16) | (m[p + 2] << 8) | m[p + 3];
    }
    for (var i = 16; i < 80; i++) {
      w[i] = _sha1Rotate(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4;
    for (var i = 0; i < 80; i++) {
      var f, k;
      if (i < 20) { f = (b & c) | (~b & d); k = 0x5A827999; }
      else if (i < 40) { f = b ^ c ^ d; k = 0x6ED9EBA1; }
      else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; }
      else { f = b ^ c ^ d; k = 0xCA62C1D6; }
      var temp = (_sha1Rotate(a, 5) + f + e + k + w[i]) >>> 0;
      e = d; d = c; c = _sha1Rotate(b, 30); b = a; a = temp;
    }

    h0 = (h0 + a) >>> 0; h1 = (h1 + b) >>> 0; h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0; h4 = (h4 + e) >>> 0;
  }

  var out = new Uint8Array(20);
  var v = [h0, h1, h2, h3, h4];
  for (var i = 0; i < 5; i++) {
    out[i * 4] = (v[i] >>> 24) & 0xff;
    out[i * 4 + 1] = (v[i] >>> 16) & 0xff;
    out[i * 4 + 2] = (v[i] >>> 8) & 0xff;
    out[i * 4 + 3] = v[i] & 0xff;
  }
  return out;
}

// ===================== SHA256（FIPS 180-2）=====================

var _sha256K = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

function _sha256Rotr(x, n) {
  return (x >>> n) | (x << (32 - n));
}

// 输入字节数组，输出 32 字节摘要
function _sha256Bytes(bytes) {
  var bitLen = bytes.length * 8;
  var hi = Math.floor(bitLen / 4294967296);
  var lo = bitLen >>> 0;
  var paddedLen = (((bytes.length + 8) >> 6) << 6) + 64;
  var m = new Uint8Array(paddedLen);
  m.set(bytes);
  m[bytes.length] = 0x80;
  m[paddedLen - 8] = (hi >>> 24) & 0xff;
  m[paddedLen - 7] = (hi >>> 16) & 0xff;
  m[paddedLen - 6] = (hi >>> 8) & 0xff;
  m[paddedLen - 5] = hi & 0xff;
  m[paddedLen - 4] = (lo >>> 24) & 0xff;
  m[paddedLen - 3] = (lo >>> 16) & 0xff;
  m[paddedLen - 2] = (lo >>> 8) & 0xff;
  m[paddedLen - 1] = lo & 0xff;

  var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
  var h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

  for (var offset = 0; offset < paddedLen; offset += 64) {
    var w = new Uint32Array(64);
    for (var i = 0; i < 16; i++) {
      var p = offset + i * 4;
      w[i] = (m[p] << 24) | (m[p + 1] << 16) | (m[p + 2] << 8) | m[p + 3];
    }
    for (var i = 16; i < 64; i++) {
      var s0 = _sha256Rotr(w[i - 15], 7) ^ _sha256Rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      var s1 = _sha256Rotr(w[i - 2], 17) ^ _sha256Rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (var i = 0; i < 64; i++) {
      var S1 = _sha256Rotr(e, 6) ^ _sha256Rotr(e, 11) ^ _sha256Rotr(e, 25);
      var ch = (e & f) ^ (~e & g);
      var t1 = (h + S1 + ch + _sha256K[i] + w[i]) >>> 0;
      var S0 = _sha256Rotr(a, 2) ^ _sha256Rotr(a, 13) ^ _sha256Rotr(a, 22);
      var maj = (a & b) ^ (a & c) ^ (b & c);
      var t2 = (S0 + maj) >>> 0;
      h = g; g = f; f = e; e = (d + t1) >>> 0;
      d = c; c = b; b = a; a = (t1 + t2) >>> 0;
    }

    h0 = (h0 + a) >>> 0; h1 = (h1 + b) >>> 0; h2 = (h2 + c) >>> 0; h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0; h5 = (h5 + f) >>> 0; h6 = (h6 + g) >>> 0; h7 = (h7 + h) >>> 0;
  }

  var out = new Uint8Array(32);
  var v = [h0, h1, h2, h3, h4, h5, h6, h7];
  for (var i = 0; i < 8; i++) {
    out[i * 4] = (v[i] >>> 24) & 0xff;
    out[i * 4 + 1] = (v[i] >>> 16) & 0xff;
    out[i * 4 + 2] = (v[i] >>> 8) & 0xff;
    out[i * 4 + 3] = v[i] & 0xff;
  }
  return out;
}

// ===================== HMAC（RFC 2104，通用实现）=====================

// hashBytesFn：输入 Uint8Array，输出摘要 Uint8Array；blockSize：哈希块大小（MD5/SHA1/SHA256 都是 64）
function _hmac(hashBytesFn, blockSize, key, msg) {
  var keyBytes = _utf8Encode(key);
  // 密钥超过块大小则先哈希压缩
  if (keyBytes.length > blockSize) {
    keyBytes = hashBytesFn(keyBytes);
  }
  var ipad = new Uint8Array(blockSize);
  var opad = new Uint8Array(blockSize);
  for (var i = 0; i < blockSize; i++) {
    var k = i < keyBytes.length ? keyBytes[i] : 0;
    ipad[i] = k ^ 0x36;
    opad[i] = k ^ 0x5c;
  }
  // inner = hash(ipad || msg)
  var msgBytes = _utf8Encode(msg);
  var inner = new Uint8Array(blockSize + msgBytes.length);
  inner.set(ipad);
  inner.set(msgBytes, blockSize);
  var innerHash = hashBytesFn(inner);
  // outer = hash(opad || inner)
  var outer = new Uint8Array(blockSize + innerHash.length);
  outer.set(opad);
  outer.set(innerHash, blockSize);
  return hashBytesFn(outer);
}

// ===================== Base64 =====================

var _B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

// 字符串 -> Base64（先按 UTF-8 编码）
function _base64Encode(str) {
  var bytes = _utf8Encode(str);
  var out = '';
  for (var i = 0; i < bytes.length; i += 3) {
    var b0 = bytes[i];
    var b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    var b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    var n = (b0 << 16) | (b1 << 8) | b2;
    out += _B64[(n >> 18) & 63] + _B64[(n >> 12) & 63] + _B64[(n >> 6) & 63] + _B64[n & 63];
  }
  var rem = bytes.length % 3;
  if (rem === 1) out = out.slice(0, -2) + '==';
  else if (rem === 2) out = out.slice(0, -1) + '=';
  return out;
}

// Base64 -> 字符串（解码后按 UTF-8 还原）
function _base64Decode(b64) {
  b64 = String(b64).replace(/[^A-Za-z0-9+/=]/g, '');
  var bytes = [];
  for (var i = 0; i < b64.length; i += 4) {
    var c0 = _B64.indexOf(b64[i]);
    var c1 = _B64.indexOf(b64[i + 1]);
    var c2 = b64[i + 2] === '=' ? 0 : _B64.indexOf(b64[i + 2]);
    var c3 = b64[i + 3] === '=' ? 0 : _B64.indexOf(b64[i + 3]);
    var n = (c0 << 18) | (c1 << 12) | (c2 << 6) | c3;
    bytes.push((n >> 16) & 0xff);
    if (b64[i + 2] !== '=') bytes.push((n >> 8) & 0xff);
    if (b64[i + 3] !== '=') bytes.push(n & 0xff);
  }
  return _utf8Decode(new Uint8Array(bytes));
}

// ===================== 对外全局函数 =====================

function _hex(bytes) {
  var s = '';
  for (var i = 0; i < bytes.length; i++) s += _h2(bytes[i]);
  return s;
}

function md5(s)          { return _hex(_md5Bytes(_utf8Encode(String(s)))); }
function sha1(s)         { return _hex(_sha1Bytes(_utf8Encode(String(s)))); }
function sha256(s)       { return _hex(_sha256Bytes(_utf8Encode(String(s)))); }
function hmacSha256(s, k){ return _hex(_hmac(_sha256Bytes, 64, String(k), String(s))); }
function hmacMd5(s, k)   { return _hex(_hmac(_md5Bytes, 64, String(k), String(s))); }
function base64Encode(s) { return _base64Encode(String(s)); }
function base64Decode(s) { return _base64Decode(String(s)); }
function urlEncode(s)    { return encodeURIComponent(String(s)); }
function urlDecode(s)    { return decodeURIComponent(String(s)); }

// ===================== CryptoJS 兼容对象（文档 5.1 节承诺的 API）=====================

// 一个"假的 WordArray"：内部其实只存 UTF-8 字符串，够支撑文档示例里的用法。
// 注意：必须给每个对象直接挂 toString（对象字面量的原型是 Object.prototype，
// 改 _word.prototype 不会生效），这样 CryptoJS.MD5('x').toString() 才有值。
function _word(str) {
  var o = { __utf8: String(str) };
  o.toString = function() { return this.__utf8; };
  return o;
}

var CryptoJS = {
  MD5: function(s)        { return _word(md5(s)); },
  SHA1: function(s)       { return _word(sha1(s)); },
  SHA256: function(s)     { return _word(sha256(s)); },
  HmacSHA256: function(s, k) { return _word(hmacSha256(s, k)); },
  HmacMD5: function(s, k)    { return _word(hmacMd5(s, k)); },
  enc: {
    Utf8: {
      parse: function(str) { return _word(str); },
      stringify: function(w) { return w.__utf8; }
    },
    Base64: {
      stringify: function(w) { return base64Encode(w.__utf8); },
      parse: function(b64) { return _word(base64Decode(b64)); }
    }
  }
};
''';

/// 在沙箱 isolate 内创建 JS 引擎实例。
///
/// - Android / Linux / Windows：用 FFI 版 QuickJS（[QuickJsRuntime2]），
///   它"原生支持 timeout 中断"——能在 JS 跑死循环时由底层强制中止，
///   这是防恶意 / 劣质插件卡死 App 的关键；同时默认**不启用 fetch 等网络能力**，
///   守住"JS 沙箱没有网络"的安全边界。
/// - iOS / macOS：用系统自带的 JavaScriptCore（[JavascriptCoreRuntime]）。
///   它同样**默认没有网络能力**（我们直接 new 它，绕开了会自动 enableFetch 的
///   [getJavascriptRuntime]），所以安全边界一致。
///   唯一的差别：JavaScriptCore 没有原生 timeout，因此"防死循环"只能依赖外层
///   [JsSandboxRunner] 的 Isolate 超时强杀兜底（对良构插件完全够用；若担心恶意
///   脚本，建议在 Android 上运行以获得 QuickJS 的原生中断保护）。
///
/// 注意：这里**没有**走 [getJavascriptRuntime]，正是为了避免它被自动 enableFetch
/// 给沙箱开通网络。
JavascriptRuntime createSandboxEngine(Duration timeout) {
  if (Platform.isAndroid || Platform.isLinux || Platform.isWindows) {
    // FFI 版 QuickJS：原生支持 timeout 中断，且默认不启用网络。
    return QuickJsRuntime2(timeout: timeout.inMilliseconds);
  }
  if (Platform.isIOS || Platform.isMacOS) {
    // iOS / macOS 走系统自带的 JavaScriptCore，同样不直接开网络。
    // JavaScriptCore 没有原生 timeout，防死循环依赖外层 Isolate 超时强杀。
    return JavascriptCoreRuntime();
  }
  // 其余平台（如 Web）暂不支持。
  throw UnsupportedError(
    '插件 JS 引擎目前不支持当前平台（${Platform.operatingSystem}）。',
  );
}
