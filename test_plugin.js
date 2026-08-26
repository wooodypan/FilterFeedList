#!/usr/bin/env node
/**
 * test_plugin.js —— 通用插件端到端测试脚本
 * ============================================================
 *  传入一个插件 JS 文件路径，完整跑一遍 App 里的插件链路：
 *
 *      模拟沙箱加载插件
 *        → buildRequest(ctx) 算出请求描述
 *        → 用 Node 内置 fetch 发【真实网络请求】
 *        → 把响应组装成 { data: 响应体 } 传给 parseResponse
 *        → 输出插件产出的文章数据
 *
 *  用法：
 *    node test_plugin.js <插件js路径> [选项]
 *
 *  选项：
 *    --page=1          页码（默认 1，会作为 ctx.page 传给插件）
 *    --pageSize=20     每页条数（默认 20）
 *    --extra='{"k":"v"}'  自定义参数，会作为 ctx.extra 传给插件
 *    --json            额外把完整文章数组以 JSON 形式打印出来
 *
 *  示例：
 *    node test_plugin.js smzdm_plugin.js --page=1 --pageSize=5
 *    node test_plugin.js ithome_rank_plugin.js --page=1 --pageSize=3
 *    node test_plugin.js my_plugin.js --extra='{"apiKey":"abc"}'
 *
 *  说明：脚本用 Node 的 vm 模拟 QuickJS 沙箱，并预置了和 App 沙箱
 *  一致的内置能力（CryptoJS + md5/sha1/hmac/base64 等全局函数），
 *  所以需要签名的插件（如 smzdm）也能直接跑。
 * ============================================================
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

// ================= 0. 解析命令行参数 =================

function parseArgs(argv) {
  const args = { pluginPath: null, page: 1, pageSize: 20, extra: {}, json: false };
  for (const a of argv) {
    if (a.startsWith('--page=')) {
      args.page = Number(a.slice('--page='.length)) || 1;
    } else if (a.startsWith('--pageSize=')) {
      args.pageSize = Number(a.slice('--pageSize='.length)) || 20;
    } else if (a.startsWith('--extra=')) {
      try {
        args.extra = JSON.parse(a.slice('--extra='.length));
      } catch (e) {
        console.error('--extra 必须是合法 JSON：', e.message);
        process.exit(1);
      }
    } else if (a === '--json') {
      args.json = true;
    } else if (args.pluginPath == null) {
      args.pluginPath = a; // 第一个非选项参数 = 插件路径
    }
  }
  return args;
}

// ================= 1. 模拟沙箱内置能力 =================
// 与 App 端 lib/plugin/js_runtime/js_builtin_libs.dart 注入的全局对象对齐：
// 加密能力用 Node 官方 crypto 实现（结果与 App 内纯 JS 实现一致：hex 小写）。

// 一个"假的 WordArray"：toString() 返回 hex，和 App 沙箱里 CryptoJS 的行为一致
function word(hex) {
  return { toString: () => hex };
}

const CryptoJS = {
  MD5: (s) => word(crypto.createHash('md5').update(String(s), 'utf8').digest('hex')),
  SHA1: (s) => word(crypto.createHash('sha1').update(String(s), 'utf8').digest('hex')),
  SHA256: (s) => word(crypto.createHash('sha256').update(String(s), 'utf8').digest('hex')),
  HmacSHA256: (s, k) =>
    word(crypto.createHmac('sha256', String(k)).update(String(s), 'utf8').digest('hex')),
  HmacMD5: (s, k) =>
    word(crypto.createHmac('md5', String(k)).update(String(s), 'utf8').digest('hex')),
  enc: {
    Utf8: {
      parse: (str) => ({ __str: String(str) }),
      stringify: (w) => w.__str,
    },
    Base64: {
      stringify: (w) => Buffer.from(w.__str, 'utf8').toString('base64'),
      parse: (b64) => ({ __str: Buffer.from(b64, 'base64').toString('utf8') }),
    },
  },
};

// 沙箱里预置的全局函数（App 的 jsBuiltins 同名同行为）
const globalFns = {
  md5: (s) => crypto.createHash('md5').update(String(s), 'utf8').digest('hex'),
  sha1: (s) => crypto.createHash('sha1').update(String(s), 'utf8').digest('hex'),
  sha256: (s) => crypto.createHash('sha256').update(String(s), 'utf8').digest('hex'),
  hmacSha256: (s, k) =>
    crypto.createHmac('sha256', String(k)).update(String(s), 'utf8').digest('hex'),
  hmacMd5: (s, k) =>
    crypto.createHmac('md5', String(k)).update(String(s), 'utf8').digest('hex'),
  base64Encode: (s) => Buffer.from(String(s), 'utf8').toString('base64'),
  base64Decode: (s) => Buffer.from(String(s), 'base64').toString('utf8'),
  urlEncode: (s) => encodeURIComponent(String(s)),
  urlDecode: (s) => decodeURIComponent(String(s)),
};

// ================= 2. 加载插件脚本到沙箱 =================

function loadPlugin(pluginPath) {
  const abs = path.resolve(pluginPath);
  if (!fs.existsSync(abs)) {
    throw new Error(`插件文件不存在：${abs}`);
  }
  const source = fs.readFileSync(abs, 'utf8');

  const sandbox = {
    // 插件里的 console.log 加前缀透传（App 沙箱也是转发到调试日志面板）
    console: {
      log: (...args) => console.log('[插件日志]', ...args),
      error: (...args) => console.error('[插件日志]', ...args),
      warn: (...args) => console.warn('[插件日志]', ...args),
    },
    CryptoJS: CryptoJS,
    ...globalFns,
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, { filename: pluginPath });

  // 校验两个核心函数存在（和 App 的 PluginDownloader 同一套要求）
  if (typeof sandbox.buildRequest !== 'function') {
    throw new Error('插件没有定义 buildRequest 函数');
  }
  if (typeof sandbox.parseResponse !== 'function') {
    throw new Error('插件没有定义 parseResponse 函数');
  }
  return sandbox;
}

// ================= 3. 执行 buildRequest =================

function buildRequest(sandbox, args) {
  const ctx = {
    page: args.page,
    pageSize: args.pageSize,
    timestamp: Date.now(),
    extra: args.extra,
  };
  const req = sandbox.buildRequest(ctx);
  if (!req || typeof req !== 'object' || typeof req.url !== 'string' || req.url === '') {
    throw new Error('buildRequest 返回值不合法：需要 { url, method, headers, params, body }');
  }
  req.method = (req.method || 'GET').toUpperCase();
  req.headers = req.headers || {};
  req.params = req.params || {};
  return { ctx, req };
}

// ================= 4. 用 Node 内置 fetch 发真实请求 =================
// 模拟 App 的 Dart 层：插件描述请求，网络由"宿主"执行。

async function executeRequest(req) {
  // 把 params 拼成 query 参数（GET 也支持 body，取决于插件的设计）
  const url = new URL(req.url);
  for (const [k, v] of Object.entries(req.params)) {
    if (v !== undefined && v !== null) {
      url.searchParams.append(k, String(v));
    }
  }

  const init = { method: req.method, headers: { ...req.headers } };

  // POST 等带 body 的请求：对象自动序列化成 JSON，字符串原样发送
  if (req.body != null) {
    init.body = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    if (!Object.keys(init.headers).some((h) => h.toLowerCase() === 'content-type')) {
      init.headers['Content-Type'] = 'application/json';
    }
  }

  const res = await fetch(url.toString(), init);
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${res.statusText}：${text.slice(0, 200)}`);
  }

  // 插件声明 responseType:'text'（HTML 源）→ 原样返回字符串；
  // 否则按 JSON 解析（失败时兜底返回字符串，保证链路不断）
  if (req.responseType === 'text') {
    return text;
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

// ================= 5. 执行 parseResponse =================

function parseResponse(sandbox, ctx, data) {
  const result = sandbox.parseResponse({ data: data }, ctx);
  if (!Array.isArray(result)) {
    throw new Error(`parseResponse 返回值不是数组，实际是 ${typeof result}`);
  }
  return result;
}

// ================= 6. 输出 =================

function summarize(articles, args) {
  console.log('\n========================================');
  console.log(`共解析出 ${articles.length} 条文章`);
  if (articles.length > 0) {
    console.log('前 3 条预览：');
    articles.slice(0, 3).forEach((a, i) => {
      console.log(`  [${i + 1}] ${a.title}`);
      console.log(`      id=${a.id} | author=${a.author || ''} | time=${a.publishTime || ''}`);
      console.log(`      url=${a.detailUrl || ''}`);
      console.log(`      thumb=${a.thumb || ''}`);
    });
  }
  console.log('========================================\n');

  if (args.json) {
    console.log(JSON.stringify(articles, null, 2));
  }
}

// ================= 7. main =================

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.pluginPath) {
    console.error('用法：node test_plugin.js <插件js路径> [--page=1] [--pageSize=20] [--extra=JSON] [--json]');
    process.exit(1);
  }

  console.log(`插件：${args.pluginPath}`);

  try {
    // 1) 加载插件（模拟沙箱）
    const sandbox = loadPlugin(args.pluginPath);

    // 2) buildRequest 构造请求描述
    const { ctx, req } = buildRequest(sandbox, args);
    console.log(`请求：${req.method} ${req.url}`);
    if (Object.keys(req.params).length > 0) {
      console.log(`参数：${JSON.stringify(req.params)}`);
    }
    if (req.responseType === 'text') {
      console.log('响应类型：text（按 HTML/纯文本接收）');
    }

    // 3) 真实网络请求
    const data = await executeRequest(req);
    const dataDesc = typeof data === 'string'
      ? `字符串（${data.length} 字符）`
      : Array.isArray(data)
        ? `数组（${data.length} 项）`
        : typeof data === 'object'
          ? `对象（keys: ${Object.keys(data).slice(0, 5).join(', ')}）`
          : `${typeof data}`;
    console.log(`响应：${dataDesc}`);

    // 4) parseResponse 解析
    const articles = parseResponse(sandbox, ctx, data);

    // 5) 输出结果
    summarize(articles, args);
    process.exit(articles.length === 0 ? 2 : 0); // 0 成功，2 表示"能跑但没数据"
  } catch (e) {
    console.error('\n测试失败：' + e.message);
    process.exit(1);
  }
}

main();
