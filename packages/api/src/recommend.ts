// ============================================================
// BiliTune API - Recommend Module
// ============================================================

import type { MusicTrack } from '@bilitune/shared';
import { apiRequest } from './client';
import { API } from '@bilitune/shared';
import { videoToMusicTrack } from './video';

// ---- Get recommendations ----

export async function getRecommendations(
  page: number = 1
): Promise<{ tracks: MusicTrack[]; hasMore: boolean }> {
  const resp = await apiRequest<{
    item?: any[];
    has_more?: boolean;
  }>(API.RECOMMEND, {
    params: { ps: 20, pn: page, fresh_type: 3, feed_version: 'V8' },
    needWbi: true,
  });

  const items = resp.data?.item || [];
  const tracks = items
    .filter((item: any) => item.goto === 'av' || item.goto === 'video')
    .map((item: any) => ({
      id: `${item.bvid}_${item.id || 0}`,
      bvid: item.bvid || '',
      aid: item.id || 0,
      cid: item.cid || item.id || 0,
      title: item.title || '',
      artist: item.owner?.name || item.author_name || '',
      artistId: item.owner?.mid || item.mid || 0,
      cover: item.pic || item.cover || '',
      duration: item.duration || 0,
      quality: '320k' as const,
      playCount: item.stat?.view || 0,
      danmakuCount: item.stat?.danmaku || 0,
      tags: item.rcmd_reason ? [item.rcmd_reason.content || ''] : [],
    }));

  return {
    tracks,
    hasMore: resp.data?.has_more || false,
  };
}

// ---- Get popular videos ----

export async function getPopularVideos(
  page: number = 1,
  pageSize: number = 20
): Promise<{ tracks: MusicTrack[] }> {
  const resp = await apiRequest<{
    list?: any[];
    no_more?: boolean;
  }>(API.POPULAR, {
    params: { pn: page, ps: pageSize },
  });

  const items = resp.data?.list || [];
  const tracks = items.map((item: any) => ({
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
    tags: [item.tname || ''],
  }));

  return { tracks };
}

// ---- Get ranking ----

export type RankingType = 'music' | 'all' | 'origin' | 'rookie';

export async function getRanking(
  rid: number = 0,
  type: RankingType = 'music'
): Promise<{ tracks: MusicTrack[] }> {
  const resp = await apiRequest<{
    list?: any[];
  }>(API.RANKING, {
    params: { rid, type },
  });

  const items = resp.data?.list || [];
  const tracks = items.map((item: any) => ({
    id: `${item.bvid}_${item.cid || 0}`,
    bvid: item.bvid || '',
    aid: item.aid || 0,
    cid: item.cid || 0,
    title: item.title || '',
    artist: item.owner?.name || item.author || '',
    artistId: item.owner?.mid || item.mid || 0,
    cover: item.pic || '',
    duration: item.duration || 0,
    quality: '320k' as const,
    playCount: item.stat?.view || item.play || 0,
    danmakuCount: item.stat?.danmaku || 0,
    tags: [],
  }));

  return { tracks };
}
