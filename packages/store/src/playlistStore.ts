// ============================================================
// BiliTune Store - Playlist Store
// ============================================================

import { create } from 'zustand';
import type { MusicPlaylist, MusicTrack } from '@bilitune/shared';
import { STORAGE_KEYS } from '@bilitune/shared';
import * as favApi from '@bilitune/api/favorite';

interface PlaylistStore {
  playlists: MusicPlaylist[];
  currentPlaylist: MusicPlaylist | null;
  isLoading: boolean;

  // Actions
  loadPlaylists: (uid: number) => Promise<void>;
  loadPlaylistContent: (mediaId: number, page?: number) => Promise<MusicTrack[]>;
  addTrackToPlaylist: (playlistId: string, track: MusicTrack) => Promise<void>;
  removeTrackFromPlaylist: (playlistId: string, aid: number) => Promise<void>;
  setCurrentPlaylist: (playlist: MusicPlaylist | null) => void;
  addLocalPlaylist: (name: string, description?: string) => void;
  removeLocalPlaylist: (id: string) => void;
  addToLocalPlaylist: (playlistId: string, track: MusicTrack) => void;
  removeFromLocalPlaylist: (playlistId: string, trackId: string) => void;
}

export const usePlaylistStore = create<PlaylistStore>((set, get) => ({
  playlists: [],
  currentPlaylist: null,
  isLoading: false,

  loadPlaylists: async (uid) => {
    set({ isLoading: true });
    try {
      const favPlaylists = await favApi.getAllFavTracks(uid);
      // Load local playlists
      const saved = localStorage.getItem(STORAGE_KEYS.FAVORITES);
      const localPlaylists: MusicPlaylist[] = saved ? JSON.parse(saved) : [];

      set({
        playlists: [...favPlaylists, ...localPlaylists],
        isLoading: false,
      });
    } catch (e) {
      console.warn('[BiliTune] Load playlists failed:', e);
      set({ isLoading: false });
    }
  },

  loadPlaylistContent: async (mediaId, page = 1) => {
    const result = await favApi.getFavFolderContent(mediaId, page);
    return result.tracks;
  },

  addTrackToPlaylist: async (playlistId, track) => {
    try {
      await favApi.addToFavorite(track.aid, 2, [Number(playlistId)]);
    } catch (e) {
      console.warn('[BiliTune] Add to playlist failed:', e);
    }
  },

  removeTrackFromPlaylist: async (playlistId, aid) => {
    try {
      await favApi.removeFromFavorite(aid, 2, [Number(playlistId)]);
    } catch (e) {
      console.warn('[BiliTune] Remove from playlist failed:', e);
    }
  },

  setCurrentPlaylist: (playlist) => set({ currentPlaylist: playlist }),

  addLocalPlaylist: (name, description = '') => {
    const playlist: MusicPlaylist = {
      id: `local_${Date.now()}`,
      title: name,
      cover: '',
      description,
      trackCount: 0,
      playCount: 0,
      owner: { mid: 0, name: '本地', face: '' },
      tracks: [],
      isFavFolder: false,
    };

    set((s) => {
      const next = [...s.playlists, playlist];
      saveLocalPlaylists(next);
      return { playlists: next };
    });
  },

  removeLocalPlaylist: (id) => {
    set((s) => {
      const next = s.playlists.filter((p) => p.id !== id);
      saveLocalPlaylists(next);
      return { playlists: next };
    });
  },

  addToLocalPlaylist: (playlistId, track) => {
    set((s) => {
      const next = s.playlists.map((p) => {
        if (p.id === playlistId && !p.tracks.find((t) => t.id === track.id)) {
          return { ...p, tracks: [...p.tracks, track], trackCount: p.trackCount + 1 };
        }
        return p;
      });
      saveLocalPlaylists(next);
      return { playlists: next };
    });
  },

  removeFromLocalPlaylist: (playlistId, trackId) => {
    set((s) => {
      const next = s.playlists.map((p) => {
        if (p.id === playlistId) {
          return {
            ...p,
            tracks: p.tracks.filter((t) => t.id !== trackId),
            trackCount: p.trackCount - 1,
          };
        }
        return p;
      });
      saveLocalPlaylists(next);
      return { playlists: next };
    });
  },
}));

function saveLocalPlaylists(playlists: MusicPlaylist[]): void {
  const localOnly = playlists.filter((p) => !p.isFavFolder);
  localStorage.setItem(STORAGE_KEYS.FAVORITES, JSON.stringify(localOnly));
}
