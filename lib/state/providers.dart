import 'dart:async';
import 'dart:math';
import 'dart:io' show Directory, File, FileSystemEntity, Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/bili_cookie_store.dart';
import '../core/network/bili_dio.dart';
import '../core/platform/app_installer.dart';
import '../core/network/bili_wbi_signer.dart';
import '../core/platform/system_media_controls.dart';
import '../core/platform/windows_hotkeys.dart';
import '../core/platform/windows_startup.dart';
import '../core/utils/format.dart';
import '../data/local/app_local_store.dart';
import '../data/models/models.dart';
import '../data/repositories/bili_auth_repository.dart';
import '../data/repositories/bili_music_repository.dart';
import '../data/services/github_release_service.dart';
import '../data/services/bili_api_service.dart';

part 'providers/core.dart';
part 'providers/settings.dart';
part 'providers/windows_and_updates.dart';
part 'providers/auth.dart';
part 'providers/search_discover.dart';
part 'providers/library.dart';
part 'providers/downloads.dart';
part 'providers/playback.dart';
