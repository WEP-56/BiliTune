// ============================================================
// BiliTune API - Favorite Module
// ============================================================

import type { MusicTrack, MusicPlaylist } from '@bilitune/shared';
import { apiRequest } from './client';
import { API } from '@bilitune/shared';
import { videoToMusicTrack } from './video';

// ---- Get favorite folder list ----

export interface FavFolder {
  id: number;
  fid: number;
  mid: number;
  title: string;
  cover: string;
  media_count: number;
  attr: number;
  intro: string;
  ctime: number;
  mtime: number;
}

export async function getFavFolderList(uid: number): Promise<FavFolder[]> {
  const resp = await apiRequest<{ list: FavFolder[]; count: number }>(
    API.FAV_FOLDER_LIST,
    { params: { up_mid: uid, type: 2 } } // type=2 for video
  );
  return resp.data?.list || [];
}

// ---- Get favorite folder content ----

export async function getFavFolderContent(
  mediaId: number,
  page: number = 1,
  pageSize: number = 20
): Promise<{ tracks: MusicTrack[]; total: number; hasMore: boolean }> {
  const resp = await apiRequest<{
    medias?: any[];
    has_more: boolean;
    info?: any;
  }>(API.FAV_FOLDER_CONTENT, {
    params: {
      media_id: mediaId,
      pn: page,
      ps: pageSize,
      type: 0,
      platform: 'web',
    },
  });

  const medias = resp.data?.medias || [];
  const tracks = medias.map((m: any) => {
    // Bilibili wraps video info in nested objects
    const video = m.page || m;
    return {
      id: `${video.bvid || ''}_${video.id || 0}`,
      bvid: video.bvid || '',
      aid: video.aid || video.id || 0,
      cid: video.cid || video.id || 0,
      title: video.title || '',
      artist: m.upper?.name || '',
      artistId: m.upper?.mid || 0,
      cover: video.cover || m.cover || '',
      duration: video.duration || 0,
      quality: '320k' as const,
      playCount: video.cnt_info?.play || 0,
      danmakuCount: video.cnt_info?.danmaku || 0,
      tags: [],
    };
  });

  return {
    tracks,
    total: medias.length,
    hasMore: resp.data?.has_more || false,
  };
}

// ---- Add/Remove from favorite ----

export async function addToFavorite(
  rid: number, // aid
  type: number = 2, // 2=video
  folderIds: number[] = [1] // default "默认收藏夹"
): Promise<void> {
  await apiRequest(API.FAV_VIDEO, {
    method: 'POST',
    data: {
      rid,
      type,
      add_media_ids: folderIds.join(','),
    },
  });
}

export async function removeFromFavorite(
  rid: number,
  type: number = 2,
  folderIds: number[] = [1]
): Promise<void> {
  await apiRequest(API.FAV_VIDEO, {
    method: 'POST',
    data: {
      rid,
      type,
      del_media_ids: folderIds.join(','),
    },
  });
}

// ---- Get all favorite tracks ----

export async function getAllFavTracks(uid: number): Promise<MusicPlaylist[]> {
  const folders = await getFavFolderList(uid);

  const playlists: MusicPlaylist[] = [];
  for (const folder of folders) {
    const content = await getFavFolderContent(folder.id, 1, 50);
    playlists.push({
      id: String(folder.id),
      title: folder.title,
      cover: folder.cover,
      description: folder.intro,
      trackCount: folder.media_count,
      playCount: 0,
      owner: { mid: uid, name: '', face: '' },
      tracks: content.tracks,
      isFavFolder: true,
    });
  }

  return playlists;
}
