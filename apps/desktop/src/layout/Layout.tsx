import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import PlayerBar from './PlayerBar';
import TopHeader from './TopHeader';

export default function Layout() {
  return (
    <div className="h-screen w-screen flex flex-col bg-[#0A0A0C] overflow-hidden">
      <div className="flex flex-1 min-h-0">
        <Sidebar />
        <div className="flex-1 flex flex-col min-w-0">
          <TopHeader />
          <main className="flex-1 overflow-y-auto overflow-x-hidden">
            <Outlet />
          </main>
        </div>
      </div>
      <PlayerBar />
    </div>
  );
}
