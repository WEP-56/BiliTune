import { useDownloadStore } from '@bilitune/store';
import { formatFileSize, formatDuration } from '@bilitune/shared';

export default function Downloads() {
  const { tasks, removeTask, pauseTask, resumeTask, clearCompleted } = useDownloadStore();

  const downloading = tasks.filter((t) => t.status === 'downloading' || t.status === 'pending');
  const completed = tasks.filter((t) => t.status === 'completed');
  const failed = tasks.filter((t) => t.status === 'failed');

  return (
    <div className="px-10 py-8 h-full overflow-y-auto">
      <h1 className="text-2xl font-extrabold text-white mb-8">下载管理</h1>

      {tasks.length === 0 ? (
        <div className="text-center py-20">
          <div className="text-6xl mb-4 opacity-20">⬇️</div>
          <p className="text-[#9E9EAF] text-lg mb-2">暂无下载任务</p>
          <p className="text-[#9E9EAF] text-sm">在歌曲上右键选择下载，即可离线收听</p>
        </div>
      ) : (
        <div className="space-y-8">
          {/* Downloading */}
          {downloading.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-white">
                  正在下载 ({downloading.length})
                </h2>
                <button
                  onClick={() => downloading.some(t => t.status === 'downloading')
                    ? useDownloadStore.getState().pauseAll()
                    : useDownloadStore.getState().resumeAll()
                  }
                  className="text-xs text-[#9E9EAF] hover:text-[#FB7299] transition-colors"
                >
                  {downloading.some(t => t.status === 'downloading') ? '全部暂停' : '全部开始'}
                </button>
              </div>
              {downloading.map((task) => (
                <DownloadItem
                  key={task.id}
                  task={task}
                  onPause={() => pauseTask(task.id)}
                  onResume={() => resumeTask(task.id)}
                  onRemove={() => removeTask(task.id)}
                />
              ))}
            </div>
          )}

          {/* Completed */}
          {completed.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-bold text-[#1D9E75]">
                  已完成 ({completed.length})
                </h2>
                <button
                  onClick={clearCompleted}
                  className="text-xs text-[#9E9EAF] hover:text-[#FB7299] transition-colors"
                >
                  清除已完成
                </button>
              </div>
              {completed.map((task) => (
                <DownloadItem
                  key={task.id}
                  task={task}
                  onPause={() => {}}
                  onResume={() => {}}
                  onRemove={() => removeTask(task.id)}
                />
              ))}
            </div>
          )}

          {/* Failed */}
          {failed.length > 0 && (
            <div>
              <h2 className="text-lg font-bold text-[#E24B4A] mb-4">
                下载失败 ({failed.length})
              </h2>
              {failed.map((task) => (
                <DownloadItem
                  key={task.id}
                  task={task}
                  onPause={() => {}}
                  onResume={() => resumeTask(task.id)}
                  onRemove={() => removeTask(task.id)}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function DownloadItem({
  task,
  onPause,
  onResume,
  onRemove,
}: {
  task: any;
  onPause: () => void;
  onResume: () => void;
  onRemove: () => void;
}) {
  const { track, status, progress, speed, fileSize, error } = task;

  const statusColors: Record<string, string> = {
    downloading: '#00AEEC',
    pending: '#9E9EAF',
    paused: '#EF9F27',
    completed: '#1D9E75',
    failed: '#E24B4A',
  };

  const statusLabels: Record<string, string> = {
    downloading: '下载中',
    pending: '等待中',
    paused: '已暂停',
    completed: '已完成',
    failed: '失败',
  };

  return (
    <div className="flex items-center gap-4 px-4 py-3 bg-[#16161A] rounded-xl mb-2 hover:bg-[#23232A] transition-colors">
      {/* Cover */}
      <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-[#23232A] to-[#16161A] flex-shrink-0 overflow-hidden">
        {track.cover ? (
          <img src={track.cover} alt="" className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-lg">♪</div>
        )}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-white truncate">{track.title}</p>
        <div className="flex items-center gap-3 text-xs">
          <span className="text-[#9E9EAF]">{track.artist}</span>
          <span style={{ color: statusColors[status] }}>{statusLabels[status]}</span>
          {(status === 'downloading' || status === 'paused') && (
            <>
              <span className="text-[#9E9EAF]">{progress.toFixed(1)}%</span>
              {speed && <span className="text-[#9E9EAF]">{speed}</span>}
            </>
          )}
          {status === 'completed' && fileSize && (
            <span className="text-[#9E9EAF]">{formatFileSize(fileSize)}</span>
          )}
          {status === 'failed' && error && (
            <span className="text-[#E24B4A] truncate">{error}</span>
          )}
        </div>
        {/* Progress bar */}
        {(status === 'downloading' || status === 'paused') && (
          <div className="w-full h-1 bg-[#33333F] rounded-full mt-2 overflow-hidden">
            <div
              className="h-full rounded-full transition-all"
              style={{
                width: `${progress}%`,
                backgroundColor: statusColors[status],
              }}
            />
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2">
        {(status === 'downloading') && (
          <button
            onClick={onPause}
            className="w-8 h-8 rounded-full bg-[#23232A] flex items-center justify-center hover:bg-[#33333A] transition-colors"
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="#9E9EAF" stroke="none">
              <rect x="6" y="4" width="4" height="16" /><rect x="14" y="4" width="4" height="16" />
            </svg>
          </button>
        )}
        {(status === 'paused' || status === 'pending') && (
          <button
            onClick={onResume}
            className="w-8 h-8 rounded-full bg-[#23232A] flex items-center justify-center hover:bg-[#33333A] transition-colors"
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="#9E9EAF" stroke="none">
              <polygon points="5 3 19 12 5 21 5 3" />
            </svg>
          </button>
        )}
        <button
          onClick={onRemove}
          className="w-8 h-8 rounded-full bg-[#23232A] flex items-center justify-center hover:bg-[#E24B4A]/20 hover:text-[#E24B4A] transition-colors"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
          </svg>
        </button>
      </div>
    </div>
  );
}
