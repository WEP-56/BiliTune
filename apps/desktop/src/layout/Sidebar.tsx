import { NavLink } from 'react-router-dom';

const navSections = [
  {
    label: '在线推荐',
    items: [
      { to: '/', label: '发现音乐', icon: MusicIcon },
      { to: '/search', label: '搜索', icon: SearchIcon },
      { to: '/now-playing', label: '正在播放', icon: PlayIcon },
    ],
  },
  {
    label: '个人音乐库',
    items: [
      { to: '/library', label: '我的音乐', icon: LibraryIcon },
      { to: '/downloads', label: '下载管理', icon: DownloadIcon },
      { to: '/settings', label: '设置', icon: SettingsIcon },
    ],
  },
];

export default function Sidebar() {
  return (
    <aside className="w-[240px] flex-shrink-0 bg-[#010103] border-r border-[#202026] flex flex-col py-8 px-5 gap-8">
      {/* Brand */}
      <div className="flex items-center gap-2.5">
        <div className="w-3 h-3 rounded-full bg-[#FB7299] shadow-[0_0_10px_rgba(251,114,153,0.5)]" />
        <span className="text-[22px] font-extrabold tracking-[-0.5px] text-white">
          BiliTune
        </span>
        <span className="text-[11px] font-semibold bg-gradient-to-r from-[#FB7299] to-[#FF94B4] text-white px-1.5 py-0.5 rounded-md">
          PC
        </span>
      </div>

      {/* Navigation */}
      {navSections.map((section) => (
        <div key={section.label} className="flex flex-col gap-1.5">
          <span className="text-[11px] font-bold text-[#9E9EAF] uppercase tracking-[1.5px] pl-3 mb-2">
            {section.label}
          </span>
          {section.items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3.5 px-3.5 py-3 rounded-[10px] text-sm font-semibold transition-all duration-200 ${
                  isActive
                    ? 'text-white bg-[#FB7299]/15 border-l-4 border-[#FB7299] pl-2.5'
                    : 'text-[#9E9EAF] hover:text-white hover:bg-[#23232A]'
                }`
              }
            >
              <item.icon />
              {item.label}
            </NavLink>
          ))}
        </div>
      ))}

      {/* Spacer */}
      <div className="flex-1" />
    </aside>
  );
}

// SVG Icons
function MusicIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 18V5l12-2v13" />
      <circle cx="6" cy="18" r="3" />
      <circle cx="18" cy="16" r="3" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

function PlayIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 22V2l18 10L3 22z" />
    </svg>
  );
}

function LibraryIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  );
}

function DownloadIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </svg>
  );
}

function SettingsIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  );
}
