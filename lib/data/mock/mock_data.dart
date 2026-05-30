import '../models/models.dart';

/// Offline mock content for the M0 UI shell. No network; covers render as
/// deterministic gradients seeded by [gradientSeed]. Replaced by real Bilibili
/// data in later milestones.
class MockData {
  const MockData._();

  static const List<Track> tracks = <Track>[
    Track(id: 't1', title: '夜的第七章', artist: '周杰伦', duration: Duration(minutes: 4, seconds: 32), type: ContentType.audio, gradientSeed: 1, playCount: 1280000),
    Track(id: 't2', title: '晴天', artist: '周杰伦', duration: Duration(minutes: 4, seconds: 29), type: ContentType.audio, gradientSeed: 2, playCount: 9800000),
    Track(id: 't3', title: '起风了', artist: '买辣椒也用券', duration: Duration(minutes: 5, seconds: 25), type: ContentType.video, gradientSeed: 3, playCount: 45000000),
    Track(id: 't4', title: 'Lemon', artist: '米津玄師', duration: Duration(minutes: 4, seconds: 16), type: ContentType.audio, gradientSeed: 4, playCount: 3200000),
    Track(id: 't5', title: '我曾', artist: '隔壁老樊', duration: Duration(minutes: 4, seconds: 51), type: ContentType.video, gradientSeed: 5, playCount: 6700000),
    Track(id: 't6', title: '光年之外', artist: 'G.E.M.邓紫棋', duration: Duration(minutes: 3, seconds: 55), type: ContentType.audio, gradientSeed: 6, playCount: 8900000),
    Track(id: 't7', title: '達拉崩吧', artist: '周深', duration: Duration(minutes: 4, seconds: 3), type: ContentType.video, gradientSeed: 7, playCount: 23000000),
    Track(id: 't8', title: 'echo', artist: 'Crusher-P', duration: Duration(minutes: 3, seconds: 30), type: ContentType.audio, gradientSeed: 8, playCount: 1500000),
    Track(id: 't9', title: '红色高跟鞋', artist: '蔡健雅', duration: Duration(minutes: 4, seconds: 12), type: ContentType.audio, gradientSeed: 9, playCount: 2100000),
    Track(id: 't10', title: '海阔天空', artist: 'Beyond', duration: Duration(minutes: 5, seconds: 25), type: ContentType.video, gradientSeed: 10, playCount: 18000000),
    Track(id: 't11', title: '关于我们', artist: '欧阳娜娜', duration: Duration(minutes: 3, seconds: 48), type: ContentType.audio, gradientSeed: 11, playCount: 980000),
    Track(id: 't12', title: '芙莉莲', artist: 'YOASOBI', duration: Duration(minutes: 3, seconds: 21), type: ContentType.video, gradientSeed: 12, playCount: 5400000),
  ];

  static Track get nowPlaying => tracks.first;

  static List<CardItem> _albumCards(int from, int count, {required String sub}) {
    return List<CardItem>.generate(count, (i) {
      final t = tracks[(from + i) % tracks.length];
      return CardItem(id: 'a${t.id}', title: t.title, subtitle: sub.isEmpty ? t.artist : sub, gradientSeed: t.gradientSeed);
    });
  }

  static const List<CardItem> _creators = <CardItem>[
    CardItem(id: 'u1', title: '周杰伦', subtitle: '1234.5万粉丝', gradientSeed: 21, shape: CoverShape.circle),
    CardItem(id: 'u2', title: '周深', subtitle: '2890.1万粉丝', gradientSeed: 22, shape: CoverShape.circle),
    CardItem(id: 'u3', title: 'G.E.M.邓紫棋', subtitle: '987.6万粉丝', gradientSeed: 23, shape: CoverShape.circle),
    CardItem(id: 'u4', title: '米津玄師', subtitle: '456.7万粉丝', gradientSeed: 24, shape: CoverShape.circle),
    CardItem(id: 'u5', title: '华晨宇', subtitle: '1567.8万粉丝', gradientSeed: 25, shape: CoverShape.circle),
    CardItem(id: 'u6', title: 'YOASOBI', subtitle: '321.0万粉丝', gradientSeed: 26, shape: CoverShape.circle),
  ];

  static List<Shelf> get shelves => <Shelf>[
        Shelf(title: '为你推荐', items: _albumCards(0, 6, sub: '')),
        Shelf(title: '热门音乐', items: _albumCards(3, 6, sub: '')),
        const Shelf(title: '关注的 UP 主', items: _creators),
        Shelf(title: '原创音乐排行榜', items: _albumCards(6, 6, sub: '')),
      ];

  static const List<String> quickPicks = <String>[
    '最近播放', '我喜欢的音乐', '每日推荐', '华语流行', '电子音乐', '动漫音乐',
  ];

  static const List<String> hotWords = <String>[
    '周杰伦新歌', '蜜雪冰城', '原神 OST', '提瓦特', '孤勇者', 'YOASOBI',
    '初音未来', '说唱', 'lofi', '钢琴曲',
  ];

  static const List<String> searchTabs = <String>['综合', '视频', '音频', 'UP主'];

  static List<CardItem> get libraryFolders => <CardItem>[
        const CardItem(id: 'f1', title: '我喜欢的音乐', subtitle: '128 首', gradientSeed: 31),
        const CardItem(id: 'f2', title: '深夜 emo 歌单', subtitle: '42 首', gradientSeed: 32),
        const CardItem(id: 'f3', title: '通勤必听', subtitle: '67 首', gradientSeed: 33),
        const CardItem(id: 'f4', title: '运动节奏', subtitle: '35 首', gradientSeed: 34),
        const CardItem(id: 'f5', title: 'ACG 精选', subtitle: '210 首', gradientSeed: 35),
        const CardItem(id: 'f6', title: '学习白噪音', subtitle: '18 首', gradientSeed: 36),
      ];

  /// (track, progress 0..1, isFinished) for the downloads list mock.
  static List<({Track track, double progress, bool done})> get downloads => <({Track track, double progress, bool done})>[
        (track: tracks[0], progress: 1.0, done: true),
        (track: tracks[1], progress: 1.0, done: true),
        (track: tracks[3], progress: 0.62, done: false),
        (track: tracks[5], progress: 0.21, done: false),
        (track: tracks[8], progress: 1.0, done: true),
      ];
}
