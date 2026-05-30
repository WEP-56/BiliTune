import { useState, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useUserStore } from '@bilitune/store';
import { useSearchStore } from '@bilitune/store';

export default function TopHeader() {
  const [query, setQuery] = useState('');
  const [isFocused, setIsFocused] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();
  const userInfo = useUserStore((s) => s.userInfo);
  const isLoggedIn = useUserStore((s) => s.isLoggedIn);
  const search = useSearchStore((s) => s.search);

  const handleSearch = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter' && query.trim()) {
        search(query.trim());
        navigate(`/search?q=${encodeURIComponent(query.trim())}`);
      }
    },
    [query, search, navigate]
  );

  return (
    <header className="h-[70px] flex-shrink-0 flex items-center justify-between px-10 border-b border-white/[0.03] z-10">
      {/* Navigation arrows */}
      <div className="flex items-center gap-4">
        <button
          onClick={() => window.history.back()}
          className="w-8 h-8 rounded-full bg-[#16161A] border border-[#202026] flex items-center justify-center text-[#9E9EAF] hover:text-white hover:bg-[#23232A] transition-colors"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>
        <button
          onClick={() => window.history.forward()}
          className="w-8 h-8 rounded-full bg-[#16161A] border border-[#202026] flex items-center justify-center text-[#9E9EAF] hover:text-white hover:bg-[#23232A] transition-colors"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="9 18 15 12 9 6" />
          </svg>
        </button>

        {/* Search */}
        <div className="relative ml-4">
          <svg
            className="absolute left-4 top-1/2 -translate-y-1/2 text-[#9E9EAF]"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </svg>
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleSearch}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            placeholder="输入歌名、UP主、BV号进行全站解析..."
            className="w-[320px] h-[38px] bg-[#16161A] border border-[#202026] rounded-[20px] pl-10 pr-5 text-sm text-white
                     outline-none transition-all duration-300 placeholder:text-[#9E9EAF]
                     focus:border-[#FB7299] focus:w-[380px] focus:bg-[#23232A]"
          />
        </div>
      </div>

      {/* User profile */}
      <div className="flex items-center gap-3 bg-black/30 px-4 py-1.5 rounded-[25px] border border-white/[0.05]">
        <div className="w-[30px] h-[30px] rounded-full bg-gradient-to-br from-[#FB7299] to-[#00AEEC] border-2 border-white flex items-center justify-center text-xs font-bold text-white">
          {userInfo?.face ? (
            <img src={userInfo.face} alt="" className="w-full h-full rounded-full object-cover" />
          ) : (
            '?'
          )}
        </div>
        <span className="text-[13px] font-semibold text-white">
          {isLoggedIn && userInfo ? userInfo.name : '未登录'}
        </span>
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#9E9EAF" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="6 9 12 15 18 9" />
        </svg>
      </div>
    </header>
  );
}
