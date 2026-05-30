// ============================================================
// BiliTune API - History Module
// ============================================================

import type { MusicTrack, PlayHistoryItem } from '@bilitune/shared';
import { apiRequest } from './client';
import { API } from '@bilitune/shared';

// ---- Get play history ----

export async function getPlayHistory(
  page: number = 1,
  pageSize: number = 20
): Promise<{ items: PlayHistoryItem[]; hasMore: boolean }> {
  const resp = await apiRequest<{
    list?: any[];
    cursor?: { max: number; has_more: number };
    has_more?: boolean;
  }>(API.HISTORY_LIST, {
    params: {
      max: 0,
      business: 'archive',
      ps: pageSize,
      type: '',
      view_at: 0,
    },
  });

  const items = (resp.data?.list || [])
    .filter((item: any) => item.business === 'archive' && item.history)
    .map((item: any): PlayHistoryItem => {
      const h = item.history;
      return {
        track: {
          id: `${h.bvid}_${h.cid}`,
          bvid: h.bvid,
          aid: h.oid || 0,
          cid: h.cid || 0,
          title: h.title || '',
          artist: h.author_name || '',
          artistId: h.mid || 0,
          cover: h.cover || h.pic || '',
          duration: h.duration || 0,
          quality: '320k',
          playCount: h.stat?.view || 0,
          danmakuCount: h.stat?.danmaku || 0,
          tags: [],
        },
        playedAt: item.view_at || 0,
        playCount: item.count || 1,
      };
    });

  return {
    items,
    hasMore: resp.data?.cursor?.has_more === 1 || resp.data?.has_more || false,
  };
}

// ---- Report play progress ----

export async function reportPlayProgress(
  aid: number,
  cid: number,
  progress: number // seconds
): Promise<void> {
  await apiRequest(API.HISTORY_REPORT, {
    method: 'POST',
    data: {
      aid,
      cid,
      progress,
      realtime: progress,
      platform: 'web',
      type: 3, // audio
    },
  });
}

// ---- Watched later (稍后再看) ----

export async function getWatchedLater(): Promise<MusicTrack[]> {
  const resp = await apiRequest<{ list?: any[] }>(API.TO_VIEW);
  const items = resp.data?.list || [];
  return items.map((item: any) => ({
    id: `${item.bvid}_${item.cid || 0}`,
    bvid: item.bvid || '',
    aid: item.aid || 0,
    cid: item.cid || 0,
    title: item.title || '',
    artist: item.owner?.name || '',
    artistId: item.owner?.mid || 0,
    cover: item.pic || '',
    duration: item.duration || 0,
    quality: '320k' as const,
    playCount: item.stat?.view || 0,
    danmakuCount: item.stat?.danmaku || 0,
    tags: [],
  }));
}

export async function addToWatchedLater(aid: number): Promise<void> {
  await apiRequest(API.TO_VIEW_ADD, {
    method: 'POST',
    data: { aid },
  });
}
