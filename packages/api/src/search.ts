// ============================================================
// BiliTune API - Search Module
// ============================================================

import type { MusicTrack, SearchResult, BiliUserBrief, MusicPlaylist } from '@bilitune/shared';
import { apiRequest } from './client';
import { API } from '@bilitune/shared';
import { parseVideoId, bv2av } from '@bilitune/shared';
import { getVideoInfo, videoToMusicTrack } from './video';

export type SearchType = 'video' | 'user' | 'media_bangumi' | 'all';

interface BiliSearchResult {
  result?: Array<{
    data: any[];
    result_type: string;
  }>;
  page?: number;
  numresults?: number;
  numPages?: number;
}

// ---- Search ----

export async function search(
  keyword: string,
  page: number = 1,
  type: SearchType = 'all',
  signal?: AbortSignal
): Promise<SearchResult> {
  const resp = await apiRequest<BiliSearchResult>(API.SEARCH, {
    params: {
      keyword,
      page,
      page_size: 20,
      search_type: type,
    },
    needWbi: true,
    signal,
  });

  const result: SearchResult = {
    tracks: [],
    playlists: [],
    users: [],
    totalPages: resp.data?.numPages || 1,
    currentPage: page,
  };

  if (resp.data?.result) {
    for (const block of resp.data.result) {
      switch (block.result_type) {
        case 'video':
          result.tracks = block.data
            .filter((v: any) => v.arcurl || v.bvid)
            .map((v: any) => searchResultToTrack(v));
          break;
        case 'user':
          result.users = block.data
            .filter((u: any) => u.mid)
            .map((u: any) => ({
              mid: u.mid,
              name: u.uname || u.name,
              face: u.upic || u.face || '',
            }));
          break;
      }
    }
  }

  return result;
}

// ---- Search suggestions ----

export async function getSearchSuggestions(): Promise<string[]> {
  const resp = await apiRequest<{ list?: Array<{ keyword: string }> }>(
    '/x/web-interface/wbi/search/default',
    { needWbi: true }
  );
  return (resp.data?.list || []).map((item: any) => item.keyword || item.name || item.show_name);
}

// ---- Smart search (BV/AV/short link detection) ----

export async function smartSearch(
  input: string,
  signal?: AbortSignal
): Promise<{ type: 'track'; data: MusicTrack } | { type: 'search'; data: SearchResult } | null> {
  const parsed = parseVideoId(input);
  if (parsed) {
    try {
      const bvid = parsed.type === 'av' ? (await import('@bilitune/shared')).av2bv(Number(parsed.id)) : parsed.id;
      const track = await getMusicTrack(bvid);
      return { type: 'track', data: track };
    } catch {
      // fall through to regular search
    }
  }

  const searchResult = await search(input, 1, 'all', signal);
  if (searchResult.tracks.length > 0 || searchResult.users.length > 0) {
    return { type: 'search', data: searchResult };
  }

  return null;
}

// ---- Helpers ----

function searchResultToTrack(item: any): MusicTrack {
  return {
    id: `${item.bvid}_${item.id || 0}`,
    bvid: item.bvid || '',
    aid: item.aid || item.id || 0,
    cid: item.cid || item.id || 0,
    title: item.title?.replace(/<em class="keyword">|<\/em>/g, '') || '',
    artist: item.author || '',
    artistId: item.mid || 0,
    cover: item.pic || item.cover || '',
    duration: parseDuration(item.duration),
    quality: '320k',
    playCount: item.play || item.video_review || 0,
    danmakuCount: item.danmaku || item.video_review || 0,
    tags: (item.tag || '').split(',').filter(Boolean),
  };
}

function parseDuration(dur: string): number {
  if (!dur) return 0;
  // Format: "mm:ss" or "hh:mm:ss"
  const parts = dur.split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return parseInt(dur) || 0;
}
