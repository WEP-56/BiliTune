// ============================================================
// BiliTune API - User Module
// ============================================================

import type { BiliUserInfo, MusicTrack } from '@bilitune/shared';
import { apiRequest } from './client';
import { API } from '@bilitune/shared';

// ---- User Info ----

export async function getUserInfo(uid: number): Promise<BiliUserInfo> {
  const resp = await apiRequest<BiliUserInfo>(API.USER_INFO, {
    params: { mid: uid },
    needWbi: true,
  });
  return resp.data;
}

// ---- User Videos ----

export async function getUserVideos(
  uid: number,
  page: number = 1,
  pageSize: number = 30
): Promise<{ videos: any[]; total: number }> {
  const resp = await apiRequest<{
    list?: { vlist?: any[] };
    page?: { count: number };
  }>(API.USER_VIDEOS, {
    params: { mid: uid, ps: pageSize, pn: page },
    needWbi: true,
  });

  return {
    videos: resp.data?.list?.vlist || [],
    total: resp.data?.page?.count || 0,
  };
}

// ---- User Stats ----

export async function getUserUpStat(uid: number): Promise<{
  archive: { view: number };
  article: { view: number };
  likes: number;
}> {
  const resp = await apiRequest(API.USER_UP_STAT, {
    params: { mid: uid },
  });
  return resp.data;
}

// ---- Follow / Unfollow ----

export async function followUser(uid: number): Promise<void> {
  await apiRequest(API.RELATION, {
    method: 'POST',
    params: { fid: uid, act: 1, re_src: 11 },
  });
}

export async function unfollowUser(uid: number): Promise<void> {
  await apiRequest(API.RELATION, {
    method: 'POST',
    params: { fid: uid, act: 2, re_src: 11 },
  });
}

// ---- Followings / Followers ----

export async function getFollowings(
  uid: number,
  page: number = 1
): Promise<{ list: any[]; total: number }> {
  const resp = await apiRequest(API.FOLLOWINGS, {
    params: { vmid: uid, pn: page, ps: 20, order: 'desc' },
  });
  return { list: resp.data?.list || [], total: resp.data?.total || 0 };
}

export async function getFollowers(
  uid: number,
  page: number = 1
): Promise<{ list: any[]; total: number }> {
  const resp = await apiRequest(API.FOLLOWERS, {
    params: { vmid: uid, pn: page, ps: 20, order: 'desc' },
  });
  return { list: resp.data?.list || [], total: resp.data?.total || 0 };
}
