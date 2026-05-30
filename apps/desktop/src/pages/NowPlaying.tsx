import { usePlayerStore } from '@bilitune/store';
import { formatDuration } from '@bilitune/shared';

export default function NowPlaying() {
  const {
    currentTrack,
    isPlaying,
    currentTime,
    duration,
    playMode,
    togglePlay,
    next,
    previous,
    seek,
    setPlayMode,
  } = usePlayerStore();

  if (!currentTrack) {
    return (
      <div className="px-10 py-8 h-full flex items-center justify-center">
        <div className="text-center">
          <div className="text-6xl mb-4 opacity-20">♪</div>
          <p className="text-[#9E9EAF] text-lg">没有正在播放的歌曲</p>
          <p className="text-[#9E9EAF] text-sm mt-1">从发现页或搜索选择一首歌曲开始播放</p>
        </div>
      </div>
    );
  }

  const progress = duration > 0 ? (currentTime / duration) * 100 : 0;

  const handleProgressClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    seek((x / rect.width) * duration);
  };

  return (
    <div className="px-10 py-8 h-full overflow-y-auto">
      <div className="flex gap-12 h-full items-start pt-5">
        {/* Left: Album Art */}
        <div className="flex-1 flex flex-col items-center text-center pt-10">
          <div className="w-[320px] h-[320px] rounded-2xl shadow-[0_25px_50px_rgba(0,0,0,0.6),0_0_40px_rgba(251,114,153,0.2)] mb-8 overflow-hidden relative bg-gradient-to-br from-[#FB7299] to-[#FF512F]">
            {currentTrack.cover ? (
              <img src={currentTrack.cover} alt="" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center">
                <span className="text-[100px] opacity-30">💿</span>
              </div>
            )}
          </div>
          <h1 className="text-[26px] font-extrabold text-white mb-2">{currentTrack.title}</h1>
          <p className="text-[15px] font-semibold text-[#FB7299] flex items-center gap-1.5">
            UP: {currentTrack.artist}
          </p>

          {/* Controls */}
          <div className="flex items-center gap-8 mt-10">
            <button onClick={() => setPlayMode('shuffle')} className={playMode === 'shuffle' ? 'text-[#FB7299]' : 'text-[#9E9EAF] hover:text-white transition-colors'}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="16 3 21 3 21 8" /><line x1="4" y1="20" x2="21" y2="3" /><polyline points="21 16 21 21 16 21" /><line x1="15" y1="15" x2="21" y2="21" /><line x1="4" y1="4" x2="9" y2="9" />
              </svg>
            </button>
            <button onClick={previous} className="text-[#D0D0D8] hover:text-white transition-colors">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                <polygon points="19 20 9 12 19 4 19 20" /><line x1="5" y1="19" x2="5" y2="5" stroke="currentColor" strokeWidth="2" />
              </svg>
            </button>
            <button onClick={togglePlay} className="w-16 h-16 rounded-full bg-white text-black flex items-center justify-center hover:scale-105 transition-transform shadow-lg">
              {isPlaying ? (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                  <rect x="6" y="4" width="4" height="16" /><rect x="14" y="4" width="4" height="16" />
                </svg>
              ) : (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                  <polygon points="5 3 19 12 5 21 5 3" />
                </svg>
              )}
            </button>
            <button onClick={next} className="text-[#D0D0D8] hover:text-white transition-colors">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                <polygon points="5 4 15 12 5 20 5 4" /><line x1="19" y1="5" x2="19" y2="19" stroke="currentColor" strokeWidth="2" />
              </svg>
            </button>
            <button onClick={() => setPlayMode('repeat-one')} className={playMode === 'repeat-one' ? 'text-[#FB7299]' : 'text-[#9E9EAF] hover:text-white transition-colors'}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="17 1 21 5 17 9" /><path d="M3 11V9a4 4 0 0 1 4-4h14" /><polyline points="7 23 3 19 7 15" /><path d="M21 13v2a4 4 0 0 1-4 4H3" />
              </svg>
            </button>
          </div>

          {/* Progress */}
          <div className="flex items-center gap-3 w-full max-w-[400px] mt-6">
            <span className="text-xs text-[#9E9EAF]">{formatDuration(currentTime)}</span>
            <div className="flex-1 h-1.5 bg-[#33333F] rounded-full cursor-pointer group" onClick={handleProgressClick}>
              <div className="h-full bg-[#FB7299] rounded-full relative" style={{ width: `${progress}%` }}>
                <div className="absolute right-0 top-1/2 -translate-y-1/2 w-3.5 h-3.5 rounded-full bg-white opacity-0 group-hover:opacity-100 transition-opacity" />
              </div>
            </div>
            <span className="text-xs text-[#9E9EAF]">{formatDuration(duration)}</span>
          </div>
        </div>

        {/* Right: Lyrics + Danmaku */}
        <div className="flex-1 h-[500px] flex flex-col border-l border-[#202026] pl-12">
          {/* Lyrics placeholder */}
          <div className="flex-1 overflow-y-auto flex flex-col gap-6 pr-2.5">
            <div className="text-lg font-semibold text-[#00AEEC] drop-shadow-[0_0_15px_rgba(0,174,236,0.4)]">
              正在加载歌词...
            </div>
            <div className="text-lg font-semibold text-[#9E9EAF]">— 暂无歌词 —</div>
            <div className="text-lg font-semibold text-[#9E9EAF]">🔍 搜索在线歌词</div>
          </div>

          {/* Danmaku overlay */}
          <div className="h-[140px] bg-black/40 rounded-xl border border-dashed border-[#FB7299]/30 mt-5 p-3.5 overflow-hidden relative">
            <span className="absolute top-1.5 right-3 text-[11px] text-[#FB7299] font-bold">
              弹幕实时层
            </span>
            <div className="mt-5 space-y-2">
              <div className="text-[13px] text-white/70 whitespace-nowrap animate-[marquee_12s_linear_infinite]">
                这个版本太绝了！！！ ⭐⭐⭐⭐⭐
              </div>
              <div className="text-[13px] text-[#00AEEC]/70 whitespace-nowrap animate-[marquee_15s_linear_infinite]" style={{ animationDelay: '3s' }}>
                每天必听系列 耳朵怀孕了
              </div>
              <div className="text-[13px] text-[#FB7299]/70 whitespace-nowrap animate-[marquee_10s_linear_infinite]" style={{ animationDelay: '6s' }}>
                已三连！UP主加油 🔥
              </div>
            </div>
          </div>
        </div>
      </div>

      <style>{`
        @keyframes marquee {
          0% { transform: translateX(500px); }
          100% { transform: translateX(-600px); }
        }
      `}</style>
    </div>
  );
}
