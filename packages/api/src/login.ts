// ============================================================
// BiliTune API - Login Module
// ============================================================

import { apiRequest, setCookies } from './client';

// ---- QR Code Login ----

export interface QRCodeData {
  url: string;
  qrcode_key: string;
}

export async function getQRCode(): Promise<QRCodeData> {
  const resp = await apiRequest<QRCodeData>(
    'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
    { method: 'GET' }
  );
  return resp.data;
}

export type QRCodeStatus =
  | { status: 'pending' }
  | { status: 'scanned'; message: string }
  | { status: 'success'; cookies: string; refreshToken: string }
  | { status: 'expired'; message: string };

export async function pollQRCode(qrcodeKey: string): Promise<QRCodeStatus> {
  const resp = await apiRequest<{
    code: number;
    message: string;
    data: {
      url?: string;
      refresh_token?: string;
      timestamp?: number;
      code?: number;
      message?: string;
    };
  }>(
    `https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key=${qrcodeKey}`,
    { method: 'GET' }
  );

  const data = resp.data;

  // Status codes from Bilibili:
  // 0: success
  // 86038: expired
  // 86090: scanned, waiting for confirm
  // 86101: not scanned

  if (data.code === undefined || data.code === null) {
    // Check if we have cookies in the response
    if (data.url) {
      // Extract cookies from redirect URL or response
      return { status: 'success', cookies: '', refreshToken: data.refresh_token || '' };
    }
  }

  switch (data.code) {
    case 0:
      return { status: 'success', cookies: '', refreshToken: data.refresh_token || '' };
    case 86038:
      return { status: 'expired', message: data.message || '二维码已过期' };
    case 86090:
      return { status: 'scanned', message: '已扫码，请在手机上确认' };
    case 86101:
    default:
      return { status: 'pending' };
  }
}

// ---- SMS Login ----

export async function sendSmsCode(phone: string, captchaKey: string): Promise<{ captcha_key: string }> {
  const resp = await apiRequest<{ captcha_key: string }>(
    'https://passport.bilibili.com/x/passport-login/web/sms/send',
    {
      method: 'POST',
      data: {
        cid: 86,
        tel: phone,
        source: 'main-fe-header',
        token: captchaKey,
        challenge: '',
        validate: '',
        seccode: '',
      },
    }
  );
  return resp.data;
}

export async function smsLogin(
  phone: string,
  code: number,
  captchaKey: string
): Promise<{ cookies: string }> {
  // We need to use a fetch that captures Set-Cookie headers
  const resp = await fetch(
    'https://passport.bilibili.com/x/passport-login/web/login/sms',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        cid: '86',
        tel: phone,
        code: String(code),
        source: 'main-fe-header',
        captcha_key: captchaKey,
      }).toString(),
      credentials: 'include',
    }
  );

  const setCookie = resp.headers.get('Set-Cookie') || '';
  return { cookies: setCookie };
}

// ---- Password Login ----

export async function passwordLogin(
  username: string,
  password: string
): Promise<{ cookies: string }> {
  // Password login requires RSA encryption of password
  // Simplified version - in production, use crypto-js for RSA
  const resp = await fetch(
    'https://passport.bilibili.com/x/passport-login/web/login',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        username,
        password,
        source: 'main-fe-header',
      }).toString(),
      credentials: 'include',
    }
  );

  const setCookie = resp.headers.get('Set-Cookie') || '';
  return { cookies: setCookie };
}

// ---- Cookie-based Login ----

export function loginWithCookies(cookieStr: string): void {
  setCookies(cookieStr);
}

// ---- Logout ----

export async function logout(): Promise<void> {
  setCookies('');
  if (typeof localStorage !== 'undefined') {
    localStorage.removeItem('bilitune_cookies');
    localStorage.removeItem('bilitune_credential');
  }
}
