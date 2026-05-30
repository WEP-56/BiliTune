import { useState } from 'react';
import { useSettingsStore, useUserStore } from '@bilitune/store';

export default function Settings() {
  const { settings, updateSetting, toggleTheme, isDark } = useSettingsStore();
  const { isLoggedIn, userInfo, loginWithQRCode, logout } = useUserStore();
  const [qrCodeUrl, setQrCodeUrl] = useState<string | null>(null);
  const [loginStatus, setLoginStatus] = useState<string>('');

  const handleLogin = async () => {
    try {
      const result = await loginWithQRCode();
      setQrCodeUrl(result.url);
      setLoginStatus('请使用B站客户端扫码登录');

      // Poll for QR code status
      const qrcodeKey = result.qrcodeKey;
      const interval = setInterval(async () => {
        const statusResult = await useUserStore.getState().pollQRCode(qrcodeKey);
        switch (statusResult) {
          case 'scanned':
            setLoginStatus('已扫码，请在手机上确认');
            break;
          case 'success':
            setLoginStatus('登录成功！');
            setQrCodeUrl(null);
            clearInterval(interval);
            break;
          case 'expired':
            setLoginStatus('二维码已过期，请重新获取');
            setQrCodeUrl(null);
            clearInterval(interval);
            break;
        }
      }, 2000);
    } catch (e) {
      setLoginStatus('获取二维码失败');
    }
  };

  return (
    <div className="px-10 py-8 h-full overflow-y-auto">
      <h1 className="text-2xl font-extrabold text-white mb-8">设置</h1>

      <div className="max-w-2xl space-y-8">
        {/* Account */}
        <section>
          <h2 className="text-lg font-bold text-white mb-4">账号</h2>
          <div className="bg-[#16161A] rounded-xl p-6 border border-[#202026]">
            {isLoggedIn && userInfo ? (
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-[#FB7299] to-[#00AEEC] overflow-hidden">
                  {userInfo.face && <img src={userInfo.face} alt="" className="w-full h-full object-cover" />}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-white">{userInfo.name}</p>
                  <p className="text-xs text-[#9E9EAF]">Lv.{userInfo.level}</p>
                </div>
                <button
                  onClick={logout}
                  className="px-4 py-2 rounded-lg bg-[#E24B4A]/10 text-[#E24B4A] text-sm font-semibold hover:bg-[#E24B4A]/20 transition-colors"
                >
                  退出登录
                </button>
              </div>
            ) : (
              <div>
                <p className="text-sm text-[#9E9EAF] mb-4">登录后同步收藏夹、播放历史和关注</p>
                <button
                  onClick={handleLogin}
                  className="px-6 py-2.5 rounded-lg bg-[#FB7299] text-white text-sm font-semibold hover:bg-[#FF94B4] transition-colors"
                >
                  扫码登录
                </button>
                {qrCodeUrl && (
                  <div className="mt-4 text-center">
                    <img src={qrCodeUrl} alt="QR Code" className="w-40 h-40 mx-auto rounded-lg" />
                    <p className="text-xs text-[#9E9EAF] mt-2">{loginStatus}</p>
                  </div>
                )}
              </div>
            )}
          </div>
        </section>

        {/* Appearance */}
        <section>
          <h2 className="text-lg font-bold text-white mb-4">外观</h2>
          <div className="bg-[#16161A] rounded-xl p-6 border border-[#202026] space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">深色模式</p>
                <p className="text-xs text-[#9E9EAF]">切换深色/浅色主题</p>
              </div>
              <button
                onClick={toggleTheme}
                className={`relative w-12 h-6 rounded-full transition-colors ${
                  isDark ? 'bg-[#FB7299]' : 'bg-[#9E9EAF]'
                }`}
              >
                <div
                  className={`absolute top-0.5 w-5 h-5 rounded-full bg-white transition-transform ${
                    isDark ? 'translate-x-6' : 'translate-x-0.5'
                  }`}
                />
              </button>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">自动播放</p>
                <p className="text-xs text-[#9E9EAF]">打开后自动播放推荐内容</p>
              </div>
              <button
                onClick={() => updateSetting('autoPlay', !settings.autoPlay)}
                className={`relative w-12 h-6 rounded-full transition-colors ${
                  settings.autoPlay ? 'bg-[#FB7299]' : 'bg-[#9E9EAF]'
                }`}
              >
                <div
                  className={`absolute top-0.5 w-5 h-5 rounded-full bg-white transition-transform ${
                    settings.autoPlay ? 'translate-x-6' : 'translate-x-0.5'
                  }`}
                />
              </button>
            </div>
          </div>
        </section>

        {/* Audio Quality */}
        <section>
          <h2 className="text-lg font-bold text-white mb-4">音质</h2>
          <div className="bg-[#16161A] rounded-xl p-6 border border-[#202026]">
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className="text-sm font-semibold text-white">默认播放音质</p>
                <p className="text-xs text-[#9E9EAF]">更高音质需要更多流量</p>
              </div>
              <select
                value={settings.audioQuality}
                onChange={(e) => updateSetting('audioQuality', e.target.value as any)}
                className="bg-[#23232A] border border-[#202026] rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-[#FB7299]"
              >
                <option value="lossless">Hi-Res 无损</option>
                <option value="320k">320K 高品</option>
                <option value="128k">128K 标准</option>
                <option value="64k">64K 流畅</option>
              </select>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">下载音质</p>
                <p className="text-xs text-[#9E9EAF]">离线下载的默认音质</p>
              </div>
              <select
                value={settings.downloadQuality}
                onChange={(e) => updateSetting('downloadQuality', e.target.value as any)}
                className="bg-[#23232A] border border-[#202026] rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-[#FB7299]"
              >
                <option value="lossless">Hi-Res 无损</option>
                <option value="320k">320K 高品</option>
                <option value="128k">128K 标准</option>
              </select>
            </div>
          </div>
        </section>

        {/* Danmaku */}
        <section>
          <h2 className="text-lg font-bold text-white mb-4">弹幕</h2>
          <div className="bg-[#16161A] rounded-xl p-6 border border-[#202026] space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">启用弹幕</p>
                <p className="text-xs text-[#9E9EAF]">在播放器页面显示实时弹幕</p>
              </div>
              <button
                onClick={() => updateSetting('danmakuEnabled', !settings.danmakuEnabled)}
                className={`relative w-12 h-6 rounded-full transition-colors ${
                  settings.danmakuEnabled ? 'bg-[#FB7299]' : 'bg-[#9E9EAF]'
                }`}
              >
                <div
                  className={`absolute top-0.5 w-5 h-5 rounded-full bg-white transition-transform ${
                    settings.danmakuEnabled ? 'translate-x-6' : 'translate-x-0.5'
                  }`}
                />
              </button>
            </div>
          </div>
        </section>

        {/* Cache */}
        <section>
          <h2 className="text-lg font-bold text-white mb-4">缓存</h2>
          <div className="bg-[#16161A] rounded-xl p-6 border border-[#202026]">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">缓存大小限制</p>
                <p className="text-xs text-[#9E9EAF]">当前：{settings.cacheSizeLimit}MB</p>
              </div>
              <select
                value={settings.cacheSizeLimit}
                onChange={(e) => updateSetting('cacheSizeLimit', Number(e.target.value))}
                className="bg-[#23232A] border border-[#202026] rounded-lg px-3 py-2 text-sm text-white outline-none focus:border-[#FB7299]"
              >
                <option value="512">512 MB</option>
                <option value="1024">1 GB</option>
                <option value="2048">2 GB</option>
                <option value="5120">5 GB</option>
              </select>
            </div>
          </div>
        </section>

        {/* About */}
        <section>
          <h2 className="text-lg font-bold text-white mb-4">关于</h2>
          <div className="bg-[#16161A] rounded-xl p-6 border border-[#202026]">
            <p className="text-sm text-[#D0D0D8]">BiliTune v1.0.0</p>
            <p className="text-xs text-[#9E9EAF] mt-1">
              Spotify × Apple Music 风格的 Bilibili 音乐客户端
            </p>
            <p className="text-xs text-[#9E9EAF] mt-2">
              基于 Bilibili 公开 API，支持 Windows / Android 双端
            </p>
          </div>
        </section>
      </div>
    </div>
  );
}
