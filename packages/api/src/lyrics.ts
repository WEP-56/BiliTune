// ============================================================
// BiliTune API - Lyrics Module
// ============================================================

import type { LyricsData, LyricLine } from '@bilitune/shared';
import { API } from '@bilitune/shared';

// ---- Get lyrics from Bilibili ----

export async function getLyrics(
  bvid: string,
  cid: number
): Promise<LyricsData | null> {
  try {
    // Bilibili provides subtitles/CC, some may contain lyrics
    const resp = await fetch(
      `https://api.bilibili.com/x/player/v2?bvid=${bvid}&cid=${cid}`,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          Referer: 'https://www.bilibili.com/',
        },
      }
    );
    const json = await resp.json();

    // Check subtitles
    const subtitles = json.data?.subtitle?.subtitles;
    if (subtitles && subtitles.length > 0) {
      const subUrl = subtitles[0].subtitle_url;
      if (subUrl && (subUrl.startsWith('http://') || subUrl.startsWith('https://'))) {
        const subResp = await fetch(subUrl);
        const subJson = await subResp.json();
        const lines = parseSubtitleJson(subJson);
        if (lines.length > 0) {
          return { lines, source: 'bilibili_cc' };
        }
      }
    }
  } catch (e) {
    console.warn('[BiliTune API] Failed to get lyrics:', e);
  }

  return null;
}

function parseSubtitleJson(data: any): LyricLine[] {
  const body = data.body || [];
  return body.map((item: any) => ({
    time: item.from || 0,
    text: item.content || '',
  }));
}

// ---- Parse LRC format ----

export function parseLRC(lrcText: string): LyricLine[] {
  const lines: LyricLine[] = [];
  const timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/g;

  for (const rawLine of lrcText.split('\n')) {
    const trimmed = rawLine.trim();
    if (!trimmed) continue;

    let match: RegExpExecArray | null;
    const times: number[] = [];

    // Reset regex
    timeRegex.lastIndex = 0;
    while ((match = timeRegex.exec(trimmed)) !== null) {
      const minutes = parseInt(match[1]);
      const seconds = parseInt(match[2]);
      const centiseconds = parseInt(match[3]);
      const time = minutes * 60 + seconds + centiseconds / (match[3].length === 2 ? 100 : 1000);
      times.push(time);
    }

    const text = trimmed.replace(timeRegex, '').trim();
    if (text && times.length > 0) {
      for (const time of times) {
        lines.push({ time, text });
      }
    }
  }

  // Sort by time
  lines.sort((a, b) => a.time - b.time);
  return lines;
}

// ---- AI Lyrics (if available) ----

export async function getAILyrics(
  songName: string,
  artist: string
): Promise<LyricsData | null> {
  // This would call a third-party lyrics API
  // For now, return null as placeholder
  return null;
}

// ---- Search lyrics ----

export async function searchLyrics(
  keyword: string
): Promise<Array<{ title: string; artist: string; lyrics: string }>> {
  // Third-party lyrics search
  // Placeholder - would integrate with a lyrics API
  return [];
}
