// ============================================================
// BiliTune Store - Player Store
// ============================================================

import { create } from 'zustand';
import type { MusicTrack, PlayMode, PlayerState } from '@bilitune/shared';
import { STORAGE_KEYS } from '@bilitune/shared';
import { shuffleArray } from '@bilitune/shared';

interface PlayerStore extends PlayerState {
  // Actions
  play: (track: MusicTrack) => void;
  playTrackAtIndex: (index: number) => void;
  pause: () => void;
  resume: () => void;
  togglePlay: () => void;
  next: () => void;
  previous: () => void;
  seek: (time: number) => void;
  setVolume: (volume: number) => void;
  toggleMute: () => void;
  setPlayMode: (mode: PlayMode) => void;
  setPlaybackRate: (rate: number) => void;
  setCurrentTime: (time: number) => void;
  setDuration: (duration: number) => void;
  // Queue
  setQueue: (tracks: MusicTrack[], startIndex?: number) => void;
  addToQueue: (track: MusicTrack) => void;
  addToQueueNext: (track: MusicTrack) => void;
  removeFromQueue: (index: number) => void;
  clearQueue: () => void;
  reorderQueue: (fromIndex: number, toIndex: number) => void;
  // Shuffle state
  shuffledQueue: MusicTrack[];
  originalQueue: MusicTrack[];
}

function getShuffledIndex(
  current: number,
  shuffledQueue: MusicTrack[],
  originalQueue: MusicTrack[],
  direction: 'next' | 'prev'
): number {
  if (shuffledQueue.length <= 1) return 0;
  const newShuffledIndex =
    direction === 'next'
      ? (current + 1) % shuffledQueue.length
      : (current - 1 + shuffledQueue.length) % shuffledQueue.length;

  return newShuffledIndex;
}

export const usePlayerStore = create<PlayerStore>((set, get) => ({
  // State
  currentTrack: null,
  queue: [],
  queueIndex: -1,
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  volume: 0.8,
  isMuted: false,
  playMode: 'sequence',
  playbackRate: 1,
  shuffledQueue: [],
  originalQueue: [],

  // Play
  play: (track) => {
    set({ currentTrack: track, isPlaying: true, currentTime: 0, queueIndex: 0 });
    saveQueue();
  },

  playTrackAtIndex: (index) => {
    const { queue, shuffledQueue, playMode } = get();
    if (index < 0 || index >= queue.length) return;
    const track =
      playMode === 'shuffle' && shuffledQueue.length > 0
        ? shuffledQueue[index]
        : queue[index];
    set({ currentTrack: track, queueIndex: index, isPlaying: true, currentTime: 0 });
    saveQueue();
  },

  pause: () => set({ isPlaying: false }),
  resume: () => set({ isPlaying: true }),

  togglePlay: () => {
    const { isPlaying, currentTrack } = get();
    if (!currentTrack) return;
    set({ isPlaying: !isPlaying });
  },

  next: () => {
    const { queue, shuffledQueue, originalQueue, queueIndex, playMode } = get();

    if (queue.length === 0) return;

    let nextIndex: number;

    if (playMode === 'shuffle') {
      const shuffledIdx = getShuffledIndex(queueIndex, shuffledQueue, originalQueue, 'next');
      const nextTrack = shuffledQueue[shuffledIdx];
      set({
        currentTrack: nextTrack,
        queueIndex: shuffledIdx,
        isPlaying: true,
        currentTime: 0,
      });
      return;
    }

    if (playMode === 'repeat-one') {
      set({ currentTime: 0 });
      return;
    }

    nextIndex = queueIndex + 1;

    if (playMode === 'repeat-all' && nextIndex >= queue.length) {
      nextIndex = 0;
    }

    if (nextIndex >= queue.length) {
      set({ isPlaying: false, currentTime: 0 });
      return;
    }

    set({
      currentTrack: queue[nextIndex],
      queueIndex: nextIndex,
      isPlaying: true,
      currentTime: 0,
    });
  },

  previous: () => {
    const { queue, shuffledQueue, originalQueue, queueIndex, currentTime, playMode } = get();

    if (queue.length === 0) return;

    // If played more than 3 seconds, restart current track
    if (currentTime > 3) {
      set({ currentTime: 0 });
      return;
    }

    if (playMode === 'shuffle') {
      const shuffledIdx = getShuffledIndex(queueIndex, shuffledQueue, originalQueue, 'prev');
      set({
        currentTrack: shuffledQueue[shuffledIdx],
        queueIndex: shuffledIdx,
        isPlaying: true,
        currentTime: 0,
      });
      return;
    }

    if (playMode === 'repeat-one') {
      set({ currentTime: 0 });
      return;
    }

    let prevIndex = queueIndex - 1;
    if (playMode === 'repeat-all' && prevIndex < 0) {
      prevIndex = queue.length - 1;
    }

    if (prevIndex < 0) {
      set({ currentTime: 0, isPlaying: true });
      return;
    }

    set({
      currentTrack: queue[prevIndex],
      queueIndex: prevIndex,
      isPlaying: true,
      currentTime: 0,
    });
  },

  seek: (time) => set({ currentTime: time }),
  setVolume: (volume) => set({ volume: Math.max(0, Math.min(1, volume)), isMuted: false }),
  toggleMute: () => set((s) => ({ isMuted: !s.isMuted })),

  setPlayMode: (mode) => {
    const { queue, queueIndex } = get();
    if (mode === 'shuffle') {
      const shuffled = shuffleArray([...queue]);
      const currentTrack = get().currentTrack;
      const shuffledIdx = currentTrack
        ? shuffled.findIndex((t) => t.id === currentTrack.id)
        : 0;
      set({
        playMode: mode,
        shuffledQueue: shuffled,
        originalQueue: [...queue],
        queueIndex: Math.max(0, shuffledIdx),
      });
    } else {
      set({ playMode: mode, shuffledQueue: [], originalQueue: [] });
    }
  },

  setPlaybackRate: (rate) => set({ playbackRate: rate }),
  setCurrentTime: (time) => set({ currentTime: time }),
  setDuration: (duration) => set({ duration }),

  // Queue
  setQueue: (tracks, startIndex = 0) => {
    if (tracks.length === 0) return;
    set({
      queue: tracks,
      queueIndex: startIndex,
      currentTrack: tracks[startIndex],
    });
    if (get().playMode === 'shuffle') {
      const shuffled = shuffleArray([...tracks]);
      const currentTrack = tracks[startIndex];
      const shuffledIdx = currentTrack
        ? shuffled.findIndex((t) => t.id === currentTrack.id)
        : 0;
      set({
        shuffledQueue: shuffled,
        originalQueue: [...tracks],
        queueIndex: Math.max(0, shuffledIdx),
      });
    }
  },

  addToQueue: (track) =>
    set((s) => ({ queue: [...s.queue, track] })),

  addToQueueNext: (track) => {
    const { queue, queueIndex } = get();
    const newQueue = [...queue];
    newQueue.splice(queueIndex + 1, 0, track);
    set({ queue: newQueue });
  },

  removeFromQueue: (index) => {
    const { queue, queueIndex } = get();
    const newQueue = queue.filter((_, i) => i !== index);
    const newIndex =
      index < queueIndex
        ? queueIndex - 1
        : index === queueIndex
        ? Math.min(queueIndex, newQueue.length - 1)
        : queueIndex;

    set({
      queue: newQueue,
      queueIndex: newIndex >= 0 ? newIndex : -1,
      currentTrack: newQueue[newIndex] || null,
      isPlaying: newIndex >= 0 ? get().isPlaying : false,
    });
  },

  clearQueue: () =>
    set({
      queue: [],
      queueIndex: -1,
      currentTrack: null,
      isPlaying: false,
      currentTime: 0,
      duration: 0,
      shuffledQueue: [],
      originalQueue: [],
    }),

  reorderQueue: (fromIndex, toIndex) => {
    const { queue, queueIndex } = get();
    const newQueue = [...queue];
    const [moved] = newQueue.splice(fromIndex, 1);
    newQueue.splice(toIndex, 0, moved);

    let newCurrIndex = queueIndex;
    if (fromIndex === queueIndex) {
      newCurrIndex = toIndex;
    } else if (fromIndex < queueIndex && toIndex >= queueIndex) {
      newCurrIndex = queueIndex - 1;
    } else if (fromIndex > queueIndex && toIndex <= queueIndex) {
      newCurrIndex = queueIndex + 1;
    }

    set({ queue: newQueue, queueIndex: newCurrIndex });
  },
}));

// ---- Persist queue to localStorage ----

function saveQueue(): void {
  try {
    const { queue, queueIndex } = usePlayerStore.getState();
    localStorage.setItem(
      STORAGE_KEYS.QUEUE,
      JSON.stringify({ queue: queue.slice(0, 100), queueIndex })
    );
  } catch {}
}

export function loadSavedQueue(): void {
  try {
    const saved = localStorage.getItem(STORAGE_KEYS.QUEUE);
    if (saved) {
      const { queue, queueIndex } = JSON.parse(saved);
      if (queue && queue.length > 0) {
        usePlayerStore.getState().setQueue(queue, queueIndex || 0);
      }
    }
  } catch {}
}
