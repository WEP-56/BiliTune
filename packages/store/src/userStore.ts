// ============================================================
// BiliTune Store - User Store
// ============================================================

import { create } from 'zustand';
import type { BiliUserInfo, LoginCredential } from '@bilitune/shared';
import { STORAGE_KEYS } from '@bilitune/shared';
import * as loginApi from '@bilitune/api/login';
import { checkLogin, getLoginUserInfo } from '@bilitune/api/client';

interface UserState {
  isLoggedIn: boolean;
  userInfo: BiliUserInfo | null;
  credential: LoginCredential | null;
  followedUids: Set<number>;

  // Actions
  init: () => Promise<void>;
  loginWithCookies: (cookies: string) => void;
  loginWithQRCode: () => Promise<{ url: string; qrcodeKey: string }>;
  pollQRCode: (qrcodeKey: string) => Promise<'pending' | 'scanned' | 'success' | 'expired'>;
  logout: () => Promise<void>;
  refreshUserInfo: () => Promise<void>;
  followUser: (uid: number) => Promise<void>;
  unfollowUser: (uid: number) => Promise<void>;
  isFollowing: (uid: number) => boolean;
}

export const useUserStore = create<UserState>((set, get) => ({
  isLoggedIn: false,
  userInfo: null,
  credential: null,
  followedUids: new Set(),

  init: async () => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.CREDENTIAL);
      if (saved) {
        const credential = JSON.parse(saved);
        set({ credential });
        loginApi.loginWithCookies(
          `SESSDATA=${credential.sessdata}; bili_jct=${credential.bili_jct}; DedeUserID=${credential.dedeuserid}`
        );
      }

      const isLogin = await checkLogin();
      if (isLogin) {
        const info = await getLoginUserInfo();
        if (info) {
          set({
            isLoggedIn: true,
            userInfo: {
              mid: info.mid,
              name: info.name,
              face: info.face,
              sex: '',
              sign: '',
              level: info.level,
              birthday: '',
              official: { role: 0, title: '', desc: '' },
              vip: { type: 0, status: 0, label: { text: '' } },
              follower: 0,
              following: 0,
            },
          });
        }
      }
    } catch (e) {
      console.warn('[BiliTune] User init failed:', e);
    }
  },

  loginWithCookies: (cookies) => {
    loginApi.loginWithCookies(cookies);
    set({ isLoggedIn: true });
  },

  loginWithQRCode: async () => {
    const qrData = await loginApi.getQRCode();
    return { url: qrData.url, qrcodeKey: qrData.qrcode_key };
  },

  pollQRCode: async (qrcodeKey) => {
    const result = await loginApi.pollQRCode(qrcodeKey);
    if (result.status === 'success') {
      loginApi.loginWithCookies(result.cookies);
      set({ isLoggedIn: true });
      get().refreshUserInfo();
    }
    return result.status;
  },

  logout: async () => {
    await loginApi.logout();
    set({ isLoggedIn: false, userInfo: null, credential: null });
    localStorage.removeItem(STORAGE_KEYS.CREDENTIAL);
    localStorage.removeItem(STORAGE_KEYS.COOKIES);
  },

  refreshUserInfo: async () => {
    try {
      const info = await getLoginUserInfo();
      if (info) {
        set((s) => ({
          isLoggedIn: true,
          userInfo: {
            ...s.userInfo,
            mid: info.mid,
            name: info.name,
            face: info.face,
            level: info.level,
          } as BiliUserInfo,
        }));
      }
    } catch {}
  },

  followUser: async (uid) => {
    try {
      const { followUser } = await import('@bilitune/api/user');
      await followUser(uid);
      set((s) => {
        const next = new Set(s.followedUids);
        next.add(uid);
        return { followedUids: next };
      });
    } catch (e) {
      console.warn('[BiliTune] Follow failed:', e);
    }
  },

  unfollowUser: async (uid) => {
    try {
      const { unfollowUser } = await import('@bilitune/api/user');
      await unfollowUser(uid);
      set((s) => {
        const next = new Set(s.followedUids);
        next.delete(uid);
        return { followedUids: next };
      });
    } catch (e) {
      console.warn('[BiliTune] Unfollow failed:', e);
    }
  },

  isFollowing: (uid) => get().followedUids.has(uid),
}));
