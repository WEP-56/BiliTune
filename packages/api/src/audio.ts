// ============================================================
// BiliTune API - Audio / Playback Module
// ============================================================

import type { BiliAudioInfo, BiliAudioQuality, AudioQuality } from '@bilitune/shared';
import { AUDIO_QUALITY_IDS } from '@bilitune/shared';
import { apiRequest } from './client';
import { API } from '@bilitune/shared';

// ---- Get Audio Stream URL ----

interface PlayUrlData {
  dash?: {
    audio: BiliAudioInfo[];
    video: any[];
    duration: number;
    minBufferTime: number;
    min_buffer_time: number;
  };
  durl?: Array<{
    url: string;
    backup_url: string[];
    size: number;
    length: number;
  }>;
  accept_description: string[];
  accept_quality: number[];
  quality: number;
  format: string;
  timelength: number;
  video_codecid: number;
}

export async function getPlayUrl(
  bvid: string,
  cid: number,
  quality: AudioQuality = '320k'
): Promise<PlayUrlData> {
  const qualityId = AUDIO_QUALITY_IDS[quality === 'lossless' ? 'lossless' : quality === '320k' ? 'high' : quality === '128k' ? 'medium' : 'low'];

  const resp = await apiRequest<PlayUrlData>(API.PLAYER_URL, {
    params: {
      bvid,
      cid,
      qn: qualityId,
      fnval: 4048, // DASH + 8K + Dolby
      fnver: 0,
      fourk: 1,
      platform: 'web',
    },
    needWbi: true,
  });

  return resp.data;
}

// ---- Get best audio URL ----

export async function getAudioUrl(
  bvid: string,
  cid: number,
  quality: AudioQuality = '320k'
): Promise<string> {
  const playData = await getPlayUrl(bvid, cid, quality);

  if (playData.dash?.audio && playData.dash.audio.length > 0) {
    const audioList = playData.dash.audio;
    // Prefer higher quality
    const sorted = [...audioList].sort((a, b) => b.bandwidth - a.bandwidth);
    return sorted[0].base_url;
  }

  // Fallback to FLV audio
  if (playData.durl && playData.durl.length > 0) {
    return playData.durl[0].url;
  }

  throw new Error('No audio stream available');
}

// ---- Get all available audio qualities ----

export async function getAudioQualities(bvid: string, cid: number): Promise<BiliAudioQuality[]> {
  const playData = await getPlayUrl(bvid, cid, 'lossless');

  if (playData.dash?.audio) {
    return playData.dash.audio.map((a) => ({
      id: a.id,
      desc: getQualityDescription(a.id),
    }));
  }

  return [];
}

function getQualityDescription(id: number): string {
  const labels: Record<number, string> = {
    30280: 'Hi-Res 无损',
    30232: '320K 高品',
    30216: '128K 标准',
    30200: '64K 流畅',
  };
  return labels[id] || `${id}`;
}

// ---- Parse audio from FLV ----

export function parseFlvAudioUrl(flvUrl: string): string {
  return flvUrl;
}

// ---- Resolve short link ----

export async function resolveShortLink(shortUrl: string): Promise<string> {
  try {
    const resp = await fetch(shortUrl, { method: 'HEAD', redirect: 'follow' });
    const finalUrl = resp.url;
    const bvMatch = finalUrl.match(/BV[a-zA-Z0-9]{10}/);
    if (bvMatch) return bvMatch[0];

    const avMatch = finalUrl.match(/av(\d+)/);
    if (avMatch) {
      const { av2bv } = await import('@bilitune/shared');
      return av2bv(Number(avMatch[1]));
    }
  } catch (e) {
    console.warn('[BiliTune API] Failed to resolve short link:', e);
  }
  return shortUrl;
}
