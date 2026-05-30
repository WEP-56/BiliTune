// ============================================================
// BiliTune API Client - Core HTTP client with WBI signing
// ============================================================

import {
  BILIBILI_API_BASE,
  DEFAULT_HEADERS,
  NAV_URL,
  STORAGE_KEYS,
} from '@bilitune/shared';
import { getMixinKey, wbiSign } from '@bilitune/shared';

export type RequestMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

export interface RequestConfig {
  method?: RequestMethod;
  params?: Record<string, any>;
  data?: any;
  headers?: Record<string, string>;
  needWbi?: boolean;
  needLogin?: boolean;
  signal?: AbortSignal;
  responseType?: 'json' | 'text' | 'blob' | 'arraybuffer';
}

export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data: T;
  ttl?: number;
}

// ---- Cookie Manager ----

let cookieStore: string = '';

export function setCookies(cookies: string): void {
  cookieStore = cookies;
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(STORAGE_KEYS.COOKIES, cookies);
  }
}

export function getCookies(): string {
  if (!cookieStore && typeof localStorage !== 'undefined') {
    cookieStore = localStorage.getItem(STORAGE_KEYS.COOKIES) || '';
  }
  return cookieStore;
}

// ---- WBI Key Manager ----

interface WbiKeys {
  imgKey: string;
  subKey: string;
  mixinKey: string;
}

let wbiKeys: WbiKeys | null = null;

async function fetchWbiKeys(): Promise<WbiKeys> {
  try {
    const resp = await fetch(NAV_URL, { headers: DEFAULT_HEADERS });
    const json = await resp.json();
    const wbiImg = json?.data?.wbi_img;

    if (wbiImg) {
      const imgKey = (wbiImg.img_url || '').split('/').pop()?.split('.')[0] || '';
      const subKey = (wbiImg.sub_url || '').split('/').pop()?.split('.')[0] || '';
      const mixinKey = getMixinKey(imgKey, subKey);

      return { imgKey, subKey, mixinKey };
    }
  } catch (e) {
    console.warn('[BiliTune API] Failed to fetch WBI keys:', e);
  }
  // Fallback keys
  return {
    imgKey: '7cd084941338484aae1ad9425b84077c',
    subKey: '4932caff0ff746eab6f01bf08b70ac45',
    mixinKey: getMixinKey(
      '7cd084941338484aae1ad9425b84077c',
      '4932caff0ff746eab6f01bf08b70ac45'
    ),
  };
}

async function getWbiKeys(): Promise<WbiKeys> {
  if (!wbiKeys) {
    wbiKeys = await fetchWbiKeys();
  }
  return wbiKeys;
}

// ---- Core Request Function ----

export async function apiRequest<T = any>(
  endpoint: string,
  config: RequestConfig = {}
): Promise<ApiResponse<T>> {
  const {
    method = 'GET',
    params = {},
    data,
    headers = {},
    needWbi = false,
    needLogin = false,
    signal,
    responseType = 'json',
  } = config;

  let finalParams = { ...params };
  const finalHeaders = { ...DEFAULT_HEADERS, ...headers };

  // Add cookies
  const cookies = getCookies();
  if (cookies) {
    finalHeaders['Cookie'] = cookies;
  }

  // WBI signing
  if (needWbi) {
    const keys = await getWbiKeys();
    finalParams = wbiSign(finalParams, keys.mixinKey);
  }

  // Build URL
  const url = new URL(endpoint, BILIBILI_API_BASE);
  if (method === 'GET') {
    Object.entries(finalParams).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        url.searchParams.append(key, String(value));
      }
    });
  }

  // Build request options
  const options: RequestInit = {
    method,
    headers: finalHeaders,
    signal,
  };

  if (method === 'POST') {
    finalHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
    options.body = new URLSearchParams(
      Object.entries(finalParams).map(([k, v]) => [k, String(v)])
    ).toString();
  }

  if (data && method === 'POST') {
    finalHeaders['Content-Type'] = 'application/json';
    options.body = JSON.stringify(data);
  }

  const response = await fetch(url.toString(), options);

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }

  if (responseType === 'text') {
    return { code: 0, message: 'ok', data: (await response.text()) as any };
  }
  if (responseType === 'blob') {
    return { code: 0, message: 'ok', data: (await response.blob()) as any };
  }
  if (responseType === 'arraybuffer') {
    return { code: 0, message: 'ok', data: (await response.arrayBuffer()) as any };
  }

  const result = await response.json();

  if (result.code !== 0) {
    throw new ApiError(result.code, result.message || 'Unknown API error');
  }

  return result;
}

// ---- API Error ----

export class ApiError extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
    this.name = 'ApiError';
  }
}

// ---- Login Check ----

export async function checkLogin(): Promise<boolean> {
  try {
    const resp = await apiRequest('/x/web-interface/nav');
    return resp.data?.isLogin === true;
  } catch {
    return false;
  }
}

export async function getLoginUserInfo(): Promise<{
  mid: number;
  name: string;
  face: string;
  level: number;
} | null> {
  try {
    const resp = await apiRequest('/x/web-interface/nav');
    if (resp.data?.isLogin && resp.data) {
      return {
        mid: resp.data.mid,
        name: resp.data.uname,
        face: resp.data.face,
        level: resp.data.level_info?.current_level || 0,
      };
    }
  } catch {
    // not logged in
  }
  return null;
}
