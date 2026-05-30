import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useSearchStore, usePlayerStore } from '@bilitune/store';
import type { MusicTrack } from '@bilitune/shared';
import { formatCount, formatDuration } from '@bilitune/shared';

export default function SearchPage() {
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const { results, isLoading, search, history, clearHistory, removeFromHistory } = useSearchStore();
  const { play, setQueue } = usePlayerStore();
  const [inputQuery, setInputQuery] = useState(query);

  useEffect(() => {
    if (query) {
      setInputQuery(query);
      search(query);
    }
  }, [query]);

  const handleSearch = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && inputQuery.trim()) {
      search(inputQuery.trim());
    }
  };

  const handlePlayTrack = (track: MusicTrack, index: number) => {
    const tracks = results?.tracks || [];
    setQueue(tracks, index);
    play(track);
  };

  if (!query && history.length > 0) {
    return (
      <div className="px-10 py-8 h-full overflow-y-auto">
        <div className="max-w-3xl mx-auto">
          <div className="relative mb-8">
            <svg className="absolute left-4 top-1/2 -translate-y-1/2 text-[#9E9EAF]" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="8" /><path d="m21 21-4.3-4.3" />
            </svg>
            <input
              type="text"
              value={inputQuery}
              onChange={(e) => setInputQuery(e.target.value)}
              onKeyDown={handleSearch}
              autoFocus
              placeholder="搜索歌曲、UP主、BV号..."
              className="w-full h-12 bg-[#16161A] border border-[#202026] rounded-xl pl-12 pr-5 text-white text-sm outline-none focus:border-[#FB7299] transition-colors"
            />
          </div>

          {/* Search History */}
          <div>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-white">搜索历史</h2>
              <button onClick={clearHistory} className="text-xs text-[#9E9EAF] hover:text-[#FB7299] transition-colors">
                清除全部
              </button>
            </div>
            <div className="flex flex-wrap gap-2">
              {history.map((h) => (
                <div key={h} className="flex items-center gap-2 bg-[#16161A] border border-[#202026] rounded-full px-4 py-2 group hover:border-[#FB7299]/30 transition-colors">
                  <button
                    onClick={() => { setInputQuery(h); search(h); }}
                    className="text-xs text-[#D0D0D8] hover:text-white"
                  >
                    {h}
                  </button>
                  <button
                    onClick={() => removeFromHistory(h)}
                    className="text-[#9E9EAF] hover:text-[#FB7299] opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="px-10 py-8 h-full overflow-y-auto">
      <div className="max-w-4xl">
        {/* Search input */}
        <div className="relative mb-8">
          <svg className="absolute left-4 top-1/2 -translate-y-1/2 text-[#9E9EAF]" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.3-4.3" />
          </svg>
          <input
            type="text"
            value={inputQuery}
            onChange={(e) => setInputQuery(e.target.value)}
            onKeyDown={handleSearch}
            placeholder="搜索歌曲、UP主、BV号..."
            className="w-full h-12 bg-[#16161A] border border-[#202026] rounded-xl pl-12 pr-5 text-white text-sm outline-none focus:border-[#FB7299] transition-colors"
          />
        </div>

        {isLoading && (
          <div className="flex items-center justify-center py-20">
            <div className="w-8 h-8 border-2 border-[#FB7299] border-t-transparent rounded-full animate-spin" />
          </div>
        )}

        {/* Results */}
        {results && (
          <div>
            {results.tracks.length > 0 && (
              <div className="mb-10">
                <h2 className="text-xl font-bold text-white mb-5">
                  视频结果 ({results.tracks.length})
                </h2>
                <div className="flex flex-col gap-1">
                  {results.tracks.map((track, index) => (
                    <div
                      key={track.id}
                      onClick={() => handlePlayTrack(track, index)}
                      className="flex items-center gap-4 px-4 py-3 rounded-xl hover:bg-[#23232A] transition-colors cursor-pointer group"
                    >
                      <span className="text-sm text-[#9E9EAF] w-8 text-right">{index + 1}</span>
                      <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-[#23232A] to-[#16161A] flex-shrink-0 overflow-hidden">
                        {track.cover ? (
                          <img src={track.cover} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-lg">♪</div>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-white truncate">{track.title}</p>
                        <p className="text-xs text-[#9E9EAF]">
                          <span className="bg-[#FB7299] text-white text-[8px] font-extrabold px-1 py-0.5 rounded mr-1">UP</span>
                          {track.artist} · {formatCount(track.playCount)}播放
                        </p>
                      </div>
                      <span className="text-[11px] text-[#9E9EAF]">{formatDuration(track.duration)}</span>
                      <div className="w-8 h-8 rounded-full bg-[#FB7299] opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center flex-shrink-0">
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="white" stroke="none">
                          <polygon points="5 3 19 12 5 21 5 3" />
                        </svg>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {results.users.length > 0 && (
              <div>
                <h2 className="text-xl font-bold text-white mb-5">UP主 ({results.users.length})</h2>
                <div className="grid grid-cols-4 gap-4">
                  {results.users.map((user) => (
                    <div
                      key={user.mid}
                      className="flex items-center gap-3 bg-[#16161A] rounded-xl p-4 border border-[#202026] hover:bg-[#23232A] transition-colors cursor-pointer"
                    >
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#FB7299] to-[#00AEEC] flex-shrink-0 overflow-hidden">
                        {user.face && <img src={user.face} alt="" className="w-full h-full object-cover" />}
                      </div>
                      <span className="text-sm font-semibold text-white truncate">{user.name}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {results.tracks.length === 0 && results.users.length === 0 && (
              <div className="text-center py-20">
                <p className="text-[#9E9EAF] text-lg mb-2">未找到相关结果</p>
                <p className="text-[#9E9EAF] text-sm">试试其他关键词或 BV 号</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
