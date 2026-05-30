// ============================================================
// BiliTune API - Video Module
// ============================================================

import type { BiliVideoInfo, BiliPage, MusicTrack, AudioQuality } from '@bilitune/shared';
import { formatCount } from '@bilitune/shared';
import { apiRequest, ApiError } from './client';
import { API } from '@bilitune/shared';

// ---- Video Info ----

export async function getVideoInfo(bvid: string): Promise<BiliVideoInfo> {
  const resp = await apiRequest<BiliVideoInfo>(API.VIDEO_INFO, {
    params: { bvid },
    needWbi: true,
  });
  return resp.data;
}

export async function getVideoPages(bvid: string): Promise<BiliPage[]> {
  const resp = await apiRequest<BiliPage[]>(API.VIDEO_PAGE_LIST, {
    params: { bvid },
  });
  return resp.data;
}

// ---- Convert video to MusicTrack ----

export function videoToMusicTrack(
  video: BiliVideoInfo,
  page?: BiliPage,
  quality: AudioQuality = '320k'
): MusicTrack {
  const cid = page?.cid || video.cid;
  const title = page
    ? `${video.title} - ${page.part}`
    : video.title;

  return {
    id: `${video.bvid}_${cid}`,
    bvid: video.bvid,
    aid: video.aid,
    cid,
    title,
    artist: video.owner.name,
    artistId: video.owner.mid,
    cover: video.cover,
    duration: page?.duration || video.duration,
    quality,
    playCount: video.stat.view,
    danmakuCount: video.stat.danmaku,
    tags: [],
  };
}

export async function getMusicTrack(
  bvid: string,
  cid?: number,
  quality: AudioQuality = '320k'
): Promise<MusicTrack> {
  const video = await getVideoInfo(bvid);
  const page = cid
    ? video.pages.find((p) => p.cid === cid)
    : video.pages[0];

  return videoToMusicTrack(video, page, quality);
}

// ---- Batch get music tracks ----

export async function getMusicTracks(
  bvids: string[],
  quality: AudioQuality = '320k'
): Promise<MusicTrack[]> {
  const results: MusicTrack[] = [];
  for (const bvid of bvids) {
    try {
      const track = await getMusicTrack(bvid, undefined, quality);
      results.push(track);
    } catch (e) {
      console.warn(`[BiliTune API] Failed to get track for ${bvid}:`, e);
    }
  }
  return results;
}
