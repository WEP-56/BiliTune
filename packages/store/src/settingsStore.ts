// ============================================================
// BiliTune Store - Settings Store
// ============================================================

import { create } from 'zustand';
import type { AppSettings, ThemeColors, AudioQuality } from '@bilitune/shared';
import { DEFAULT_SETTINGS, STORAGE_KEYS, DARK_THEME, LIGHT_THEME } from '@bilitune/shared';

interface SettingsStore {
  settings: AppSettings;
  theme: ThemeColors;
  isDark: boolean;

  // Actions
  init: () => void;
  updateSetting: <K extends keyof AppSettings>(key: K, value: AppSettings[K]) => void;
  resetSettings: () => void;
  setAudioQuality: (quality: AudioQuality) => void;
  toggleTheme: () => void;
}

function getEffectiveTheme(theme: AppSettings['theme']): 'dark' | 'light' {
  if (theme === 'auto') {
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return 'dark';
  }
  return theme;
}

export const useSettingsStore = create<SettingsStore>((set, get) => ({
  settings: { ...DEFAULT_SETTINGS },
  theme: DARK_THEME,
  isDark: true,

  init: () => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.SETTINGS);
      if (saved) {
        const parsed = JSON.parse(saved);
        const settings = { ...DEFAULT_SETTINGS, ...parsed };
        const effective = getEffectiveTheme(settings.theme);
        set({
          settings,
          theme: effective === 'dark' ? DARK_THEME : LIGHT_THEME,
          isDark: effective === 'dark',
        });
        return;
      }
    } catch {}

    const effective = getEffectiveTheme(DEFAULT_SETTINGS.theme);
    set({
      theme: effective === 'dark' ? DARK_THEME : LIGHT_THEME,
      isDark: effective === 'dark',
    });
  },

  updateSetting: (key, value) => {
    set((s) => {
      const newSettings = { ...s.settings, [key]: value };
      localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(newSettings));

      if (key === 'theme') {
        const effective = getEffectiveTheme(value as AppSettings['theme']);
        return {
          settings: newSettings,
          theme: effective === 'dark' ? DARK_THEME : LIGHT_THEME,
          isDark: effective === 'dark',
        };
      }

      return { settings: newSettings };
    });
  },

  resetSettings: () => {
    localStorage.removeItem(STORAGE_KEYS.SETTINGS);
    const effective = getEffectiveTheme(DEFAULT_SETTINGS.theme);
    set({
      settings: { ...DEFAULT_SETTINGS },
      theme: effective === 'dark' ? DARK_THEME : LIGHT_THEME,
      isDark: effective === 'dark',
    });
  },

  setAudioQuality: (quality) => {
    const { updateSetting } = get();
    updateSetting('audioQuality', quality);
  },

  toggleTheme: () => {
    const { settings } = get();
    const newTheme = settings.theme === 'dark' ? 'light' : 'dark';
    get().updateSetting('theme', newTheme);
  },
}));
