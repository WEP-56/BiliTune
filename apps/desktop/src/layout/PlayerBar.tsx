import { useNavigate } from 'react-router-dom';
import { usePlayerStore } from '@bilitune/store';
import { formatDuration } from '@bilitune/shared';

export default function PlayerBar() {
  const navigate = useNavigate();
  const {
    currentTrack,
    isPlaying,
    currentTime,
    duration,
    volume,
    isMuted,
    playMode,
    playbackRate,
    togglePlay,
    next,
    previous,
    seek,
    setVolume,
    toggleMute,
    setPlayMode,
  } = usePlayerStore();

  if (!currentTrack) {
    return (
      <div className="h-[90px] flex-shrink-0 bg-[#111115] border-t border-[#202026] flex items-center justify-center text-sm text-[#9E9EAF]">
        选择一首歌曲开始播放
      </div>
    );
  }

  const progress = duration > 0 ? (currentTime / duration) * 100 : 0;

  const handleProgressClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const pct = x / rect.width;
    seek(pct * duration);
  };

  const playModeIcon = () => {
    switch (playMode) {
      case 'shuffle':
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#FB7299" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="16 3 21 3 21 8" />
            <line x1="4" y1="20" x2="21" y2="3" />
            <polyline points="21 16 21 21 16 21" />
            <line x1="15" y1="15" x2="21" y2="21" />
            <line x1="4" y1="4" x2="9" y2="9" />
          </svg>
        );
      case 'repeat-one':
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#FB7299" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="17 1 21 5 17 9" />
            <path d="M3 11V9a4 4 0 0 1 4-4h14" />
            <polyline points="7 23 3 19 7 15" />
            <path d="M21 13v2a4 4 0 0 1-4 4H3" />
            <text x="10" y="14" fontSize="8" fontWeight="700" fill="#FB7299">1</text>
          </svg>
        );
      case 'repeat-all':
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#FB7299" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="17 1 21 5 17 9" />
            <path d="M3 11V9a4 4 0 0 1 4-4h14" />
            <polyline points="7 23 3 19 7 15" />
            <path d="M21 13v2a4 4 0 0 1-4 4H3" />
          </svg>
        );
      default:
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#9E9EAF" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="17 1 21 5 17 9" />
            <path d="M3 11V9a4 4 0 0 1 4-4h14" />
            <polyline points="7 23 3 19 7 15" />
            <path d="M21 13v2a4 4 0 0 1-4 4H3" />
          </svg>
        );
    }
  };

  const cyclePlayMode = () => {
    const modes: Array<'sequence' | 'shuffle' | 'repeat-all' | 'repeat-one'> = [
      'sequence',
      'shuffle',
      'repeat-all',
      'repeat-one',
    ];
    const idx = modes.indexOf(playMode);
    setPlayMode(modes[(idx + 1) % modes.length]);
  };

  return (
    <div className="h-[90px] flex-shrink-0 bg-[#111115] border-t border-[#202026] flex items-center justify-between px-8 z-10">
      {/* Left: Track info */}
      <div className="flex items-center gap-3.5 w-[28%] min-w-0">
        <div
          className="w-[56px] h-[56px] rounded-lg flex-shrink-0 bg-gradient-to-br from-[#FB7299] to-[#00AEEC] cursor-pointer overflow-hidden"
          onClick={() => navigate('/now-playing')}
        >
          {currentTrack.cover ? (
            <img src={currentTrack.cover} alt="" className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-white opacity-30 text-xl">
              ♪
            </div>
          )}
        </div>
        <div className="min-w-0">
          <h4 className="text-sm font-semibold text-white truncate">{currentTrack.title}</h4>
          <p className="text-xs text-[#9E9EAF] truncate">
            UP: {currentTrack.artist}
          </p>
        </div>
        <button className="text-[#9E9EAF] hover:text-[#FB7299] transition-colors">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" stroke="none">
            <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
          </svg>
        </button>
      </div>

      {/* Center: Controls */}
      <div className="flex flex-col items-center gap-2.5 w-[44%]">
        <div className="flex items-center gap-6">
          {/* Play mode */}
          <button onClick={cyclePlayMode} className="text-[#9E9EAF] hover:text-white transition-colors">
            {playModeIcon()}
          </button>

          {/* Previous */}
          <button onClick={previous} className="text-[#D0D0D8] hover:text-white transition-colors">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <polygon points="19 20 9 12 19 4 19 20" />
              <line x1="5" y1="19" x2="5" y2="5" stroke="currentColor" strokeWidth="2" />
            </svg>
          </button>

          {/* Play/Pause */}
          <button
            onClick={togglePlay}
            className="w-9 h-9 rounded-full bg-white text-black flex items-center justify-center hover:scale-105 transition-transform"
          >
            {isPlaying ? (
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                <rect x="6" y="4" width="4" height="16" />
                <rect x="14" y="4" width="4" height="16" />
              </svg>
            ) : (
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                <polygon points="5 3 19 12 5 21 5 3" />
              </svg>
            )}
          </button>

          {/* Next */}
          <button onClick={next} className="text-[#D0D0D8] hover:text-white transition-colors">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <polygon points="5 4 15 12 5 20 5 4" />
              <line x1="19" y1="5" x2="19" y2="19" stroke="currentColor" strokeWidth="2" />
            </svg>
          </button>

          {/* Loop mode already shown, this is playMode */}
        </div>

        {/* Progress bar */}
        <div className="flex items-center gap-3 w-full max-w-[560px]">
          <span className="text-[11px] text-[#9E9EAF] w-10 text-right tabular-nums">
            {formatDuration(currentTime)}
          </span>
          <div
            className="flex-1 h-1 bg-[#33333F] rounded-full cursor-pointer group relative"
            onClick={handleProgressClick}
          >
            <div
              className="h-full bg-[#FB7299] rounded-full relative"
              style={{ width: `${progress}%` }}
            >
              <div className="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-white opacity-0 group-hover:opacity-100 transition-opacity" />
            </div>
          </div>
          <span className="text-[11px] text-[#9E9EAF] w-10 tabular-nums">
            {formatDuration(duration)}
          </span>
        </div>
      </div>

      {/* Right: Utilities */}
      <div className="flex items-center gap-5 justify-end w-[28%]">
        {/* Danmaku toggle */}
        <button className="flex items-center gap-2 text-xs font-bold bg-[#00AEEC]/10 border border-[#00AEEC] text-[#00AEEC] px-3.5 py-1.5 rounded-[20px] hover:bg-[#00AEEC] hover:text-white transition-all">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
          </svg>
          弹幕
        </button>

        {/* Volume */}
        <div className="flex items-center gap-2">
          <button onClick={toggleMute} className="text-[#9E9EAF] hover:text-white transition-colors">
            {isMuted || volume === 0 ? (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" />
                <line x1="23" y1="9" x2="17" y2="15" />
                <line x1="17" y1="9" x2="23" y2="15" />
              </svg>
            ) : volume < 0.5 ? (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" />
                <path d="M15.54 8.46a5 5 0 0 1 0 7.07" />
              </svg>
            ) : (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" />
                <path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07" />
              </svg>
            )}
          </button>
          <input
            type="range"
            min="0"
            max="100"
            value={isMuted ? 0 : volume * 100}
            onChange={(e) => setVolume(Number(e.target.value) / 100)}
            className="w-20 h-1 accent-[#FB7299]"
          />
        </div>

        {/* Playlist */}
        <button className="text-[#9E9EAF] hover:text-white transition-colors">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="8" y1="6" x2="21" y2="6" />
            <line x1="8" y1="12" x2="21" y2="12" />
            <line x1="8" y1="18" x2="21" y2="18" />
            <line x1="3" y1="6" x2="3.01" y2="6" />
            <line x1="3" y1="12" x2="3.01" y2="12" />
            <line x1="3" y1="18" x2="3.01" y2="18" />
          </svg>
        </button>
      </div>
    </div>
  );
}
