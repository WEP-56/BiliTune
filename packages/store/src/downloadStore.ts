// ============================================================
// BiliTune Store - Download Store
// ============================================================

import { create } from 'zustand';
import type { DownloadTask, MusicTrack, AudioQuality } from '@bilitune/shared';
import { STORAGE_KEYS, generateId } from '@bilitune/shared';

interface DownloadStore {
  tasks: DownloadTask[];
  activeCount: number;

  // Actions
  init: () => void;
  addTask: (track: MusicTrack, quality?: AudioQuality) => string;
  removeTask: (id: string) => void;
  pauseTask: (id: string) => void;
  resumeTask: (id: string) => void;
  pauseAll: () => void;
  resumeAll: () => void;
  clearCompleted: () => void;
  updateProgress: (id: string, progress: number, speed?: string) => void;
  completeTask: (id: string, filePath: string, fileSize: number) => void;
  failTask: (id: string, error: string) => void;
}

export const useDownloadStore = create<DownloadStore>((set, get) => ({
  tasks: [],
  activeCount: 0,

  init: () => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.DOWNLOADS);
      if (saved) {
        const tasks = JSON.parse(saved);
        // Reset in-progress downloads
        const reset = tasks.map((t: DownloadTask) =>
          t.status === 'downloading' ? { ...t, status: 'paused' as const, progress: t.progress || 0 } : t
        );
        set({ tasks: reset });
      }
    } catch {}
  },

  addTask: (track, quality) => {
    const id = generateId();
    const task: DownloadTask = {
      id,
      track: { ...track, quality: quality || track.quality },
      status: 'pending',
      progress: 0,
      speed: '',
      createdAt: Date.now(),
    };

    set((s) => {
      const next = [task, ...s.tasks];
      saveTasks(next);
      return { tasks: next };
    });

    return id;
  },

  removeTask: (id) => {
    set((s) => {
      const next = s.tasks.filter((t) => t.id !== id);
      saveTasks(next);
      return { tasks: next };
    });
  },

  pauseTask: (id) => {
    set((s) => {
      const next = s.tasks.map((t) =>
        t.id === id ? { ...t, status: 'paused' as const } : t
      );
      saveTasks(next);
      return { tasks: next, activeCount: Math.max(0, s.activeCount - 1) };
    });
  },

  resumeTask: (id) => {
    set((s) => {
      const next = s.tasks.map((t) =>
        t.id === id && t.status === 'paused'
          ? { ...t, status: 'pending' as const }
          : t
      );
      saveTasks(next);
      return { tasks: next, activeCount: s.activeCount + 1 };
    });
  },

  pauseAll: () => {
    set((s) => ({
      tasks: s.tasks.map((t) =>
        t.status === 'downloading' ? { ...t, status: 'paused' as const } : t
      ),
      activeCount: 0,
    }));
    saveTasks(get().tasks);
  },

  resumeAll: () => {
    set((s) => ({
      tasks: s.tasks.map((t) =>
        t.status === 'paused' ? { ...t, status: 'pending' as const } : t
      ),
    }));
    saveTasks(get().tasks);
  },

  clearCompleted: () => {
    set((s) => {
      const next = s.tasks.filter((t) => t.status !== 'completed');
      saveTasks(next);
      return { tasks: next };
    });
  },

  updateProgress: (id, progress, speed) => {
    set((s) => ({
      tasks: s.tasks.map((t) =>
        t.id === id
          ? { ...t, status: 'downloading' as const, progress, speed: speed || t.speed }
          : t
      ),
    }));
  },

  completeTask: (id, filePath, fileSize) => {
    set((s) => {
      const next = s.tasks.map((t) =>
        t.id === id
          ? { ...t, status: 'completed' as const, progress: 100, filePath, fileSize }
          : t
      );
      saveTasks(next);
      return { tasks: next, activeCount: Math.max(0, s.activeCount - 1) };
    });
  },

  failTask: (id, error) => {
    set((s) => {
      const next = s.tasks.map((t) =>
        t.id === id
          ? { ...t, status: 'failed' as const, error }
          : t
      );
      saveTasks(next);
      return { tasks: next, activeCount: Math.max(0, s.activeCount - 1) };
    });
  },
}));

function saveTasks(tasks: DownloadTask[]): void {
  try {
    localStorage.setItem(STORAGE_KEYS.DOWNLOADS, JSON.stringify(tasks));
  } catch {}
}
