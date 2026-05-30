// ============================================================
// BiliTune Store - Search Store
// ============================================================

import { create } from 'zustand';
import type { SearchResult, MusicTrack, BiliUserBrief } from '@bilitune/shared';
import * as searchApi from '@bilitune/api/search';

interface SearchStore {
  query: string;
  results: SearchResult | null;
  isLoading: boolean;
  history: string[];
  suggestions: string[];

  // Actions
  search: (keyword: string, page?: number) => Promise<void>;
  smartSearch: (input: string) => Promise<{ type: 'track'; data: MusicTrack } | { type: 'search'; data: SearchResult } | null>;
  loadMore: () => Promise<void>;
  setQuery: (query: string) => void;
  clearResults: () => void;
  loadSuggestions: () => Promise<void>;
  addToHistory: (keyword: string) => void;
  removeFromHistory: (keyword: string) => void;
  clearHistory: () => void;
}

export const useSearchStore = create<SearchStore>((set, get) => ({
  query: '',
  results: null,
  isLoading: false,
  history: [],
  suggestions: [],

  search: async (keyword, page = 1) => {
    set({ query: keyword, isLoading: true });
    try {
      const results = await searchApi.search(keyword, page);
      set({ results, isLoading: false });
      get().addToHistory(keyword);
    } catch (e) {
      console.warn('[BiliTune] Search failed:', e);
      set({ isLoading: false });
    }
  },

  smartSearch: async (input) => {
    set({ isLoading: true });
    try {
      const result = await searchApi.smartSearch(input);
      set({ isLoading: false });
      return result;
    } catch (e) {
      set({ isLoading: false });
      return null;
    }
  },

  loadMore: async () => {
    const { query, results, isLoading } = get();
    if (!results || isLoading) return;

    const nextPage = results.currentPage + 1;
    if (nextPage > results.totalPages) return;

    set({ isLoading: true });
    try {
      const newResults = await searchApi.search(query, nextPage);
      set({
        results: {
          ...newResults,
          tracks: [...results.tracks, ...newResults.tracks],
          users: [...results.users, ...newResults.users],
        },
        isLoading: false,
      });
    } catch (e) {
      set({ isLoading: false });
    }
  },

  setQuery: (query) => set({ query }),
  clearResults: () => set({ results: null, query: '' }),

  loadSuggestions: async () => {
    try {
      const suggestions = await searchApi.getSearchSuggestions();
      set({ suggestions });
    } catch {}
  },

  addToHistory: (keyword) => {
    set((s) => {
      const next = [keyword, ...s.history.filter((k) => k !== keyword)].slice(0, 20);
      localStorage.setItem('bilitune_search_history', JSON.stringify(next));
      return { history: next };
    });
  },

  removeFromHistory: (keyword) => {
    set((s) => {
      const next = s.history.filter((k) => k !== keyword);
      localStorage.setItem('bilitune_search_history', JSON.stringify(next));
      return { history: next };
    });
  },

  clearHistory: () => {
    set({ history: [] });
    localStorage.removeItem('bilitune_search_history');
  },
}));

// Load search history on init
try {
  const saved = localStorage.getItem('bilitune_search_history');
  if (saved) {
    useSearchStore.setState({ history: JSON.parse(saved) });
  }
} catch {}
