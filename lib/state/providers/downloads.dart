part of '../providers.dart';

@immutable
class DownloadQueueState {
  const DownloadQueueState({
    this.tasks = const <DownloadTask>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DownloadTask> tasks;
  final bool isLoading;
  final String? errorMessage;

  int get completedCount =>
      tasks.where((task) => task.status == DownloadTaskStatus.completed).length;

  List<DownloadTask> get completedTasks => tasks
      .where(
        (task) =>
            task.status == DownloadTaskStatus.completed &&
            task.savePath != null &&
            task.savePath!.isNotEmpty,
      )
      .toList(growable: false);

  List<Track> get downloadedTracks => completedTasks
      .map(
        (task) => Track(
          id: 'download-${task.id}',
          title: task.title,
          artist: task.artist,
          duration: Duration.zero,
          type: task.type,
          gradientSeed: task.gradientSeed,
          coverUrl: task.coverUrl,
          playCount: task.downloadedBytes,
          bvid: task.bvid,
          aid: task.aid,
          cid: task.cid,
          audioId: task.audioId,
          sourceUrl: Uri.file(task.savePath!).toString(),
        ),
      )
      .toList(growable: false);

  int get activeCount => tasks
      .where((task) => task.status == DownloadTaskStatus.downloading)
      .length;

  double get storageProgress {
    final total = tasks.fold<int>(
      0,
      (sum, task) => sum + (task.totalBytes ?? 0),
    );
    if (total <= 0) return 0;
    final downloaded = tasks.fold<int>(
      0,
      (sum, task) => sum + task.downloadedBytes,
    );
    return (downloaded / total).clamp(0.0, 1.0);
  }

  DownloadQueueState copyWith({
    List<DownloadTask>? tasks,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return DownloadQueueState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class DownloadQueueNotifier extends Notifier<DownloadQueueState> {
  bool _bootstrapped = false;
  bool _scheduling = false;
  final _cancelTokens = <String, CancelToken>{};
  final _lastProgressPersistAt = <String, DateTime>{};

  @override
  DownloadQueueState build() {
    ref.listen<DownloadSettings>(downloadSettingsProvider, (previous, next) {
      if (previous?.maxConcurrent != next.maxConcurrent) {
        unawaited(_scheduleDownloads());
      }
    });
    if (!_bootstrapped && !_skipNetworkBootstrap) {
      _bootstrapped = true;
      unawaited(_bootstrap());
    }
    return const DownloadQueueState();
  }

  Future<void> _bootstrap() async {
    state = const DownloadQueueState(isLoading: true);
    try {
      final loaded = await ref.read(appLocalStoreProvider).readDownloadTasks();
      var changed = false;
      final tasks = loaded
          .map((task) {
            if (task.status != DownloadTaskStatus.downloading) return task;
            changed = true;
            return task.copyWith(status: DownloadTaskStatus.paused);
          })
          .toList(growable: false);
      if (changed) await _persist(tasks);
      state = state.copyWith(tasks: tasks, isLoading: false);
      unawaited(_scheduleDownloads());
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> enqueueTrack(
    Track track, {
    String outputFileType = 'audio',
    String? savePath,
  }) async {
    final settings = ref.read(downloadSettingsProvider);
    final task = DownloadTask.fromTrack(
      track,
      outputFileType: outputFileType == 'audio'
          ? settings.outputFileType
          : outputFileType,
      savePath: savePath,
    );
    final tasks = <DownloadTask>[task, ...state.tasks];
    await _persist(tasks);
    state = state.copyWith(tasks: tasks, errorMessage: null);
    await _scheduleDownloads();
  }

  Future<void> pauseTask(String id) async {
    final token = _cancelTokens.remove(id);
    if (token != null && !token.isCancelled) {
      token.cancel('paused');
      return;
    }
    await _updateTask(
      id,
      (task) => task.copyWith(status: DownloadTaskStatus.paused),
    );
    await _scheduleDownloads();
  }

  Future<void> resumeTask(String id) async {
    await _updateTask(
      id,
      (task) => task.copyWith(status: DownloadTaskStatus.queued),
    );
    await _scheduleDownloads();
  }

  Future<void> completeTask(String id) async => _updateTask(
    id,
    (task) => task.copyWith(
      status: DownloadTaskStatus.completed,
      downloadedBytes: task.totalBytes ?? task.downloadedBytes,
    ),
  );

  Future<void> failTask(String id, String message) async => _updateTask(
    id,
    (task) =>
        task.copyWith(status: DownloadTaskStatus.failed, errorMessage: message),
  );

  Future<void> removeTask(String id) async {
    final token = _cancelTokens.remove(id);
    if (token != null && !token.isCancelled) {
      token.cancel('removed');
    }
    final tasks = state.tasks
        .where((task) => task.id != id)
        .toList(growable: false);
    await _persist(tasks);
    state = state.copyWith(tasks: tasks);
    await _scheduleDownloads();
  }

  Future<void> clear() async {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel('cleared');
    }
    _cancelTokens.clear();
    await _persist(const <DownloadTask>[]);
    state = state.copyWith(tasks: const <DownloadTask>[]);
  }

  Future<void> refresh() async {
    _bootstrapped = false;
    await _bootstrap();
  }

  Future<void> _scheduleDownloads() async {
    if (_scheduling) return;
    _scheduling = true;
    try {
      final limit = ref.read(downloadSettingsProvider).maxConcurrent;
      while (state.activeCount < limit) {
        final task = _nextQueuedTask();
        if (task == null) return;
        await _updateTask(
          task.id,
          (task) => task.copyWith(
            status: DownloadTaskStatus.downloading,
            errorMessage: null,
          ),
        );
        unawaited(_startDownload(task.id));
      }
    } finally {
      _scheduling = false;
    }
  }

  Future<void> _updateTask(
    String id,
    DownloadTask Function(DownloadTask task) update,
  ) async {
    final tasks = state.tasks
        .map((task) => task.id == id ? update(task) : task)
        .toList(growable: false);
    await _persist(tasks);
    state = state.copyWith(tasks: tasks, errorMessage: null);
  }

  Future<void> _startDownload(String id) async {
    final task = _taskById(id);
    if (task == null ||
        task.status == DownloadTaskStatus.completed ||
        task.status == DownloadTaskStatus.paused ||
        task.status == DownloadTaskStatus.cancelled) {
      return;
    }
    if (_cancelTokens.containsKey(id)) return;

    final token = CancelToken();
    _cancelTokens[id] = token;

    try {
      final source = await ref
          .read(biliMusicRepositoryProvider)
          .resolvePlaybackSource(_trackFromTask(task));
      final directory = await _downloadDirectory();
      final savePath =
          task.savePath ?? _joinPath(directory.path, _fileName(task, source));

      await _updateTask(
        id,
        (task) => task.copyWith(
          savePath: savePath,
          audioCodecs: _audioCodecs(source),
          audioBandwidth: source.bandwidth,
        ),
      );

      await ref
          .read(biliDioProvider)
          .download(
            source.url,
            savePath,
            cancelToken: token,
            options: Options(
              headers: const <String, String>{
                'User-Agent': biliUserAgent,
                'Referer': biliReferer,
                'Origin': 'https://www.bilibili.com',
              },
              receiveTimeout: const Duration(minutes: 5),
            ),
            onReceiveProgress: (received, total) {
              _setProgress(id, received, total > 0 ? total : null);
            },
          );

      final bytes = await File(savePath).length();
      await _updateTask(
        id,
        (task) => task.copyWith(
          status: DownloadTaskStatus.completed,
          downloadedBytes: bytes,
          totalBytes: bytes,
          errorMessage: null,
        ),
      );
    } catch (error) {
      if ((error is DioException && CancelToken.isCancel(error)) ||
          token.isCancelled) {
        await _updateTask(
          id,
          (task) => task.copyWith(status: DownloadTaskStatus.paused),
        );
      } else {
        await failTask(id, error.toString());
      }
    } finally {
      _cancelTokens.remove(id);
      _lastProgressPersistAt.remove(id);
      unawaited(_scheduleDownloads());
    }
  }

  void _setProgress(String id, int received, int? total) {
    final tasks = state.tasks
        .map(
          (task) => task.id == id
              ? task.copyWith(downloadedBytes: received, totalBytes: total)
              : task,
        )
        .toList(growable: false);
    state = state.copyWith(tasks: tasks, errorMessage: null);

    final now = DateTime.now();
    final last = _lastProgressPersistAt[id];
    if (last == null ||
        now.difference(last) > const Duration(milliseconds: 700)) {
      _lastProgressPersistAt[id] = now;
      unawaited(_persist(tasks));
    }
  }

  DownloadTask? _taskById(String id) {
    for (final task in state.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  DownloadTask? _nextQueuedTask() {
    for (final task in state.tasks.reversed) {
      if (task.status == DownloadTaskStatus.queued) return task;
    }
    return null;
  }

  Track _trackFromTask(DownloadTask task) {
    return Track(
      id:
          task.bvid ??
          task.aid?.toString() ??
          task.audioId?.toString() ??
          task.id,
      title: task.title,
      artist: task.artist,
      duration: Duration.zero,
      type: task.type,
      gradientSeed: task.gradientSeed,
      coverUrl: task.coverUrl,
      bvid: task.bvid,
      aid: task.aid,
      cid: task.cid,
      audioId: task.audioId,
    );
  }

  Future<Directory> _downloadDirectory() async {
    final settings = ref.read(downloadSettingsProvider);
    final customPath = settings.directoryPath;
    final directory = customPath == null || customPath.trim().isEmpty
        ? await _defaultDownloadDirectory()
        : Directory(customPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _joinPath(String left, String right) {
    final separator = Platform.pathSeparator;
    return left.endsWith(separator) ? '$left$right' : '$left$separator$right';
  }

  String _fileName(DownloadTask task, BiliPlaybackSource source) {
    final title = _sanitizeFileName(task.title).trim();
    final artist = _sanitizeFileName(task.artist).trim();
    final prefix = artist.isEmpty ? title : '$artist - $title';
    final safePrefix = prefix.isEmpty ? task.id : prefix;
    final suffix = task.id.length <= 8
        ? _sanitizeFileName(task.id)
        : _sanitizeFileName(task.id.substring(task.id.length - 8));
    return '${safePrefix.substring(0, min(safePrefix.length, 96))}-$suffix.${_extension(source)}';
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  String _extension(BiliPlaybackSource source) {
    final codecs = source.codecs?.toLowerCase() ?? '';
    final mimeType = source.mimeType?.toLowerCase() ?? '';
    if (source.isLossless || codecs.contains('flac')) return 'flac';
    if (mimeType.contains('mp4') || codecs.contains('mp4a')) return 'm4a';
    return 'm4s';
  }

  String? _audioCodecs(BiliPlaybackSource source) {
    if (source.isLossless) return 'flac';
    return source.codecs;
  }

  Future<void> _persist(List<DownloadTask> tasks) async {
    await ref.read(appLocalStoreProvider).saveDownloadTasks(tasks);
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, DownloadQueueState>(
      DownloadQueueNotifier.new,
    );
