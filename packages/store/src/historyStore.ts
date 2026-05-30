// ============================================================
// BiliTune Store - History Store
// ============================================================

import { create } from 'zustand';
import type { PlayHistoryItem, MusicTrack } from '@bilitune/shared';
import { STORAGE_KEYS, formatDate } from '@bilitune/shared';
import * as historyApi from '@bilitune/api/history';

interface HistoryStore {
  items: PlayHistoryItem[];
  isLoading: boolean;
  hasMore: boolean;

  // Actions
  init: () => void;
  loadHistory: (page?: number) => Promise<void>;
  addToHistory: (track: MusicTrack) => void;
  clearHistory: () => void;
  removeItem: (trackId: string) => void;
  getGroupedHistory: () => Map<string, PlayHistoryItem[]>;
}

export const useHistoryStore = create<HistoryStore>((set, get) => ({
  items: [],
  isLoading: false,
  hasMore: true,

  init: () => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.HISTORY);
      if (saved) {
        set({ items: JSON.parse(saved) });
      }
    } catch {}
  },

  loadHistory: async (page = 1) => {
    set({ isLoading: true });
    try {
      const result = await historyApi.getPlayHistory(page);
      set((s) => ({
        items: page === 1 ? result.items : [...s.items, ...result.items],
        hasMore: result.hasMore,
        isLoading: false,
      }));
    } catch (e) {
      console.warn('[BiliTune] Load history failed:', e);
      set({ isLoading: false });
    }
  },

  addToHistory: (track) => {
    const item: PlayHistoryItem = {
      track,
      playedAt: Math.floor(Date.now() / 1000),
      playCount: 1,
    };

    set((s) => {
      const existing = s.items.find((i) => i.track.id === track.id);
      if (existing) {
        const next = [
          { ...existing, playedAt: item.playedAt, playCount: existing.playCount + 1 },
          ...s.items.filter((i) => i.track.id !== track.id),
        ].slice(0, 500);
        saveHistory(next);
        return { items: next };
      }

      const next = [item, ...s.items].slice(0, 500);
      saveHistory(next);
      return { items: next };
    });
  },

  clearHistory: () => {
    set({ items: [] });
    localStorage.removeItem(STORAGE_KEYS.HISTORY);
  },

  removeItem: (trackId) => {
    set((s) => {
      const next = s.items.filter((i) => i.track.id !== trackId);
      saveHistory(next);
      return { items: next };
    });
  },

  getGroupedHistory: () => {
    const grouped = new Map<string, PlayHistoryItem[]>();
    for (const item of get().items) {
      const dateKey = formatDate(item.playedAt);
      if (!grouped.has(dateKey)) {
        grouped.set(dateKey, []);
      }
      grouped.get(dateKey)!.push(item);
    }
    return grouped;
  },
}));

function saveHistory(items: PlayHistoryItem[]): void {
  try {
    localStorage.setItem(STORAGE_KEYS.HISTORY, JSON.stringify(items));
  } catch {}
}
