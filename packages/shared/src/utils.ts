// ============================================================
// BiliTune Utilities
// ============================================================

import { WBI_MIXIN_KEY_ENC_TABLE } from './constants';

// ---- BV <-> AV conversion ----

const XOR_CODE = 23442827791579n;
const MASK_CODE = 2251799813685247n;
const MAX_AID = 1n << 51n;
const ALPHABET = 'FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf';

export function av2bv(aid: number): string {
  const bytes = ['B', 'V', '1', '0', '0', '0', '0', '0', '0', '0', '0', '0'];
  let bvIndex = bytes.length - 1;
  let tmp = (MAX_AID | BigInt(aid)) ^ XOR_CODE;

  while (tmp > 0) {
    bytes[bvIndex] = ALPHABET[Number(tmp % 58n)];
    tmp = tmp / 58n;
    bvIndex -= 1;
  }

  [bytes[3], bytes[9]] = [bytes[9], bytes[3]];
  [bytes[4], bytes[7]] = [bytes[7], bytes[4]];

  return bytes.join('');
}

export function bv2av(bvid: string): number {
  const bv = bvid.replace('BV', '').split('');
  [bv[1], bv[7]] = [bv[7], bv[1]];
  [bv[2], bv[5]] = [bv[5], bv[2]];

  let tmp = 0n;
  for (const char of bv) {
    const idx = ALPHABET.indexOf(char);
    if (idx === -1) continue;
    tmp = tmp * 58n + BigInt(idx);
  }

  let aid = (tmp & MASK_CODE) ^ XOR_CODE;
  aid = aid & MAX_AID;

  return Number(aid);
}

// ---- WBI Signing ----

export function getMixinKey(imgKey: string, subKey: string): string {
  const rawKey = imgKey + subKey;
  let result = '';
  for (const idx of WBI_MIXIN_KEY_ENC_TABLE) {
    if (idx < rawKey.length) {
      result += rawKey[idx];
    }
  }
  return result.substring(0, 32);
}

export function wbiSign(params: Record<string, any>, mixinKey: string): Record<string, any> {
  const wts = Math.floor(Date.now() / 1000);
  const sorted = Object.keys({ ...params, wts })
    .sort()
    .reduce<Record<string, any>>((acc, key) => {
      acc[key] = params[key] ?? wts;
      return acc;
    }, {});

  const query = Object.entries(sorted)
    .map(([k, v]) => {
      let val = v;
      if (typeof val === 'object') val = JSON.stringify(val);
      return `${encodeURIComponent(k)}=${encodeURIComponent(String(val))}`;
    })
    .join('&');

  const wRid = md5(query + mixinKey);

  return { ...params, wts, w_rid: wRid };
}

// Simple MD5 implementation (for WBI signing in browser/RN)
// In production, use a proper crypto library
function md5(str: string): string {
  function rotateLeft(n: number, s: number): number {
    return (n << s) | (n >>> (32 - s));
  }

  function toHex(n: number): string {
    let hex = '';
    for (let i = 0; i < 4; i++) {
      hex += ((n >> (i * 8 + 4)) & 0x0f).toString(16);
      hex += ((n >> (i * 8)) & 0x0f).toString(16);
    }
    return hex;
  }

  const bytes: number[] = [];
  for (let i = 0; i < str.length; i++) {
    bytes.push(str.charCodeAt(i) & 0xff);
  }

  const msgLen = bytes.length;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) {
    bytes.push(0);
  }

  const bitLen = msgLen * 8;
  for (let i = 0; i < 4; i++) {
    bytes.push((bitLen >>> (i * 8)) & 0xff);
  }
  for (let i = 4; i < 8; i++) {
    bytes.push(0);
  }

  const S = [7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21];
  const K: number[] = [];
  for (let i = 0; i < 64; i++) {
    K[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296);
  }

  let a0 = 0x67452301,
    b0 = 0xefcdab89,
    c0 = 0x98badcfe,
    d0 = 0x10325476;

  for (let i = 0; i < bytes.length; i += 64) {
    const M: number[] = [];
    for (let j = 0; j < 16; j++) {
      M[j] =
        bytes[i + j * 4] |
        (bytes[i + j * 4 + 1] << 8) |
        (bytes[i + j * 4 + 2] << 16) |
        (bytes[i + j * 4 + 3] << 24);
    }

    let A = a0,
      B = b0,
      C = c0,
      D = d0;

    for (let j = 0; j < 64; j++) {
      let F: number, g: number;
      if (j < 16) {
        F = (B & C) | (~B & D);
        g = j;
      } else if (j < 32) {
        F = (D & B) | (~D & C);
        g = (5 * j + 1) % 16;
      } else if (j < 48) {
        F = B ^ C ^ D;
        g = (3 * j + 5) % 16;
      } else {
        F = C ^ (B | ~D);
        g = (7 * j) % 16;
      }

      F = (F + A + K[j] + M[g]) | 0;
      A = D;
      D = C;
      C = B;
      B = (B + rotateLeft(F, S[(j >>> 2) * 4 + (j % 4)])) | 0;
    }

    a0 = (a0 + A) | 0;
    b0 = (b0 + B) | 0;
    c0 = (c0 + C) | 0;
    d0 = (d0 + D) | 0;
  }

  return toHex(a0) + toHex(b0) + toHex(c0) + toHex(d0);
}

// ---- Time formatting ----

export function formatDuration(seconds: number): string {
  if (!seconds || seconds < 0) return '00:00';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    return `${h}:${pad(m)}:${pad(s)}`;
  }
  return `${pad(m)}:${pad(s)}`;
}

function pad(n: number): string {
  return n.toString().padStart(2, '0');
}

// ---- Format numbers ----

export function formatCount(count: number): string {
  if (count >= 100000000) {
    return (count / 100000000).toFixed(1) + '亿';
  }
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + '万';
  }
  return count.toString();
}

// ---- Format file size ----

export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return (bytes / Math.pow(1024, i)).toFixed(1) + ' ' + units[i];
}

// ---- Parse BV/AV from input ----

export function parseVideoId(input: string): { type: 'bv' | 'av'; id: string } | null {
  const trimmed = input.trim();

  // BV号
  const bvMatch = trimmed.match(/^BV[a-zA-Z0-9]{10}$/);
  if (bvMatch) return { type: 'bv', id: bvMatch[0] };

  // AV号
  const avMatch = trimmed.match(/^av(\d+)$/i);
  if (avMatch) return { type: 'av', id: avMatch[1] };

  // 短链接 b23.tv
  if (trimmed.includes('b23.tv')) return null; // needs HTTP redirect

  // 纯数字当做AV号
  if (/^\d+$/.test(trimmed)) return { type: 'av', id: trimmed };

  return null;
}

// ---- Debounce / Throttle ----

export function debounce<T extends (...args: any[]) => any>(fn: T, delay: number) {
  let timer: ReturnType<typeof setTimeout>;
  return (...args: Parameters<T>) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

export function throttle<T extends (...args: any[]) => any>(fn: T, delay: number) {
  let last = 0;
  return (...args: Parameters<T>) => {
    const now = Date.now();
    if (now - last >= delay) {
      last = now;
      fn(...args);
    }
  };
}

// ---- ID generation ----

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 9);
}

// ---- Color utilities ----

export function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? { r: parseInt(result[1], 16), g: parseInt(result[2], 16), b: parseInt(result[3], 16) }
    : null;
}

export function rgbToHex(r: number, g: number, b: number): string {
  return '#' + [r, g, b].map((x) => x.toString(16).padStart(2, '0')).join('');
}

// ---- Cookie parser ----

export function parseCookies(cookieStr: string): Record<string, string> {
  const cookies: Record<string, string> = {};
  cookieStr.split(';').forEach((pair) => {
    const [key, ...val] = pair.trim().split('=');
    if (key) cookies[key.trim()] = val.join('=').trim();
  });
  return cookies;
}

export function serializeCookies(cookies: Record<string, string>): string {
  return Object.entries(cookies)
    .map(([k, v]) => `${k}=${v}`)
    .join('; ');
}

// ---- Safe JSON parse ----

export function safeJsonParse<T>(str: string, fallback: T): T {
  try {
    return JSON.parse(str) as T;
  } catch {
    return fallback;
  }
}

// ---- Array utils ----

export function shuffleArray<T>(arr: T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// ---- Date formatting ----

export function formatDate(ts: number): string {
  const date = new Date(ts * 1000);
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);

  if (minutes < 1) return '刚刚';
  if (minutes < 60) return `${minutes}分钟前`;
  if (hours < 24) return `${hours}小时前`;
  if (days < 7) return `${days}天前`;

  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// ---- Platform detection ----

export function isDesktop(): boolean {
  if (typeof window === 'undefined') return false;
  return !/Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
}

export function isAndroid(): boolean {
  if (typeof navigator === 'undefined') return false;
  return /Android/i.test(navigator.userAgent);
}
