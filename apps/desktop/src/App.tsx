import { useEffect } from 'react';
import { Routes, Route } from 'react-router-dom';
import Layout from './layout/Layout';
import Discover from './pages/Discover';
import SearchPage from './pages/SearchPage';
import NowPlaying from './pages/NowPlaying';
import Library from './pages/Library';
import Downloads from './pages/Downloads';
import Settings from './pages/Settings';
import { useSettingsStore } from '@bilitune/store';
import { useUserStore } from '@bilitune/store';
import { usePlayerStore } from '@bilitune/store';

export default function App() {
  const initSettings = useSettingsStore((s) => s.init);
  const initUser = useUserStore((s) => s.init);

  useEffect(() => {
    initSettings();
    initUser();
  }, []);

  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Discover />} />
        <Route path="search" element={<SearchPage />} />
        <Route path="now-playing" element={<NowPlaying />} />
        <Route path="library" element={<Library />} />
        <Route path="downloads" element={<Downloads />} />
        <Route path="settings" element={<Settings />} />
      </Route>
    </Routes>
  );
}
