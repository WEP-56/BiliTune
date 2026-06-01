import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class GithubReleaseAsset {
  const GithubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  final String name;
  final Uri downloadUrl;
  final int sizeBytes;

  factory GithubReleaseAsset.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final url = json['browser_download_url']?.toString().trim() ?? '';
    if (name.isEmpty || url.isEmpty) {
      throw StateError('Invalid GitHub release asset payload.');
    }
    return GithubReleaseAsset(
      name: name,
      downloadUrl: Uri.parse(url),
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class GithubReleaseInfo {
  const GithubReleaseInfo({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.body,
    required this.assets,
    required this.publishedAt,
  });

  final String tagName;
  final String name;
  final Uri htmlUrl;
  final String body;
  final List<GithubReleaseAsset> assets;
  final DateTime? publishedAt;

  factory GithubReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assetsRaw = json['assets'];
    final assets = <GithubReleaseAsset>[];
    if (assetsRaw is List) {
      for (final item in assetsRaw.whereType<Map>()) {
        assets.add(GithubReleaseAsset.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final htmlUrl = json['html_url']?.toString().trim() ?? '';
    final tagName = json['tag_name']?.toString().trim() ?? '';
    if (htmlUrl.isEmpty || tagName.isEmpty) {
      throw StateError('Invalid GitHub release payload.');
    }

    final publishedAtRaw = json['published_at']?.toString().trim();
    final rawName = json['name']?.toString().trim() ?? '';
    return GithubReleaseInfo(
      tagName: tagName,
      name: rawName.isEmpty ? tagName : rawName,
      htmlUrl: Uri.parse(htmlUrl),
      body: json['body']?.toString().trim() ?? '',
      assets: List<GithubReleaseAsset>.unmodifiable(assets),
      publishedAt: publishedAtRaw == null || publishedAtRaw.isEmpty
          ? null
          : DateTime.tryParse(publishedAtRaw),
    );
  }
}

class GithubUpdateService {
  GithubUpdateService(this._dio);

  static const _repositoryApiBase =
      'https://api.github.com/repos/WEP-56/BiliTune';
  static const _updatesFolderName = 'BiliTune';

  final Dio _dio;

  Future<String> fetchLatestVersionTag() async {
    final response = await _dio.getUri(
      Uri.parse('$_repositoryApiBase/tags?per_page=50'),
    );
    final data = response.data;
    if (data is! List) {
      throw StateError('Unexpected GitHub tags response.');
    }

    String? latestTag;
    ReleaseVersion? latestVersion;
    for (final item in data.whereType<Map>()) {
      final tag = item['name']?.toString().trim();
      if (tag == null || tag.isEmpty) continue;
      try {
        final version = ReleaseVersion.parse(tag);
        if (latestVersion == null || version.compareTo(latestVersion) > 0) {
          latestTag = tag;
          latestVersion = version;
        }
      } catch (_) {}
    }

    if (latestTag == null) {
      throw StateError('No version tag was found on GitHub.');
    }
    return latestTag;
  }

  Future<GithubReleaseInfo> fetchLatestRelease() async {
    final latestTag = await fetchLatestVersionTag();
    return fetchReleaseByTag(latestTag);
  }

  Future<GithubReleaseInfo> fetchReleaseByTag(String tag) async {
    final encodedTag = Uri.encodeComponent(tag);
    final response = await _dio.getUri(
      Uri.parse('$_repositoryApiBase/releases/tags/$encodedTag'),
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('Unexpected GitHub response.');
    }
    return GithubReleaseInfo.fromJson(Map<String, dynamic>.from(data));
  }

  GithubReleaseAsset? selectInstallerAsset(GithubReleaseInfo release) {
    final assets = release.assets;
    if (assets.isEmpty) return null;

    if (Platform.isAndroid) {
      for (final asset in assets) {
        final name = asset.name.toLowerCase();
        if (name.endsWith('.apk')) {
          return asset;
        }
      }
      return null;
    }

    if (Platform.isWindows) {
      GithubReleaseAsset? fallback;
      for (final asset in assets) {
        final name = asset.name.toLowerCase();
        if (name.endsWith('.msi')) {
          return asset;
        }
        if (name.endsWith('.exe')) {
          fallback ??= asset;
        }
        if ((name.contains('setup') || name.contains('installer')) &&
            (name.endsWith('.exe') || name.endsWith('.msi'))) {
          return asset;
        }
      }
      return fallback;
    }

    return assets.first;
  }

  Future<File> downloadInstallerAsset(GithubReleaseAsset asset) async {
    Directory base;
    try {
      base = await getTemporaryDirectory();
    } catch (_) {
      base = await getApplicationDocumentsDirectory();
    }

    final directory = Directory(
      _joinPath(base.path, _updatesFolderName),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File(_joinPath(directory.path, asset.name));
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.downloadUri(
      asset.downloadUrl,
      file.path,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    return file;
  }
}

class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  factory ReleaseVersion.parse(String raw) {
    final normalized = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final base = normalized.split('+').first.split('-').first;
    final parts = base.split('.');
    if (parts.length < 3) {
      throw FormatException('Invalid version: $raw');
    }

    final major = int.parse(parts[0]);
    final minor = int.parse(parts[1]);
    final patch = int.parse(parts[2]);
    return ReleaseVersion(major, minor, patch);
  }

  @override
  int compareTo(ReleaseVersion other) {
    final majorDiff = major.compareTo(other.major);
    if (majorDiff != 0) return majorDiff;
    final minorDiff = minor.compareTo(other.minor);
    if (minorDiff != 0) return minorDiff;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

bool isRemoteReleaseNewer({
  required String currentVersion,
  required String remoteTag,
}) {
  try {
    final current = ReleaseVersion.parse(currentVersion);
    final remote = ReleaseVersion.parse(remoteTag);
    return remote.compareTo(current) > 0;
  } catch (_) {
    return false;
  }
}

String _joinPath(String left, String right) {
  final separator = Platform.pathSeparator;
  return left.endsWith(separator) ? '$left$right' : '$left$separator$right';
}
