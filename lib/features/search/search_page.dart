import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/favorite_folder_dialogs.dart';
import '../../state/providers.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/track_row.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    ref
        .read(searchProvider.notifier)
        .search(value, mode: ref.read(searchProvider).mode);
  }

  void _scheduleSuggestions(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(searchProvider.notifier).loadSuggestions(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= AppLayout.desktopBreakpoint
        ? AppSpacing.s6
        : AppSpacing.s4;
    final state = ref.watch(searchProvider);
    final play = ref.read(playbackProvider.notifier);

    final tabs = <({String label, SearchMode mode})>[
      (label: '音乐', mode: SearchMode.music),
      (label: '全站视频', mode: SearchMode.all),
    ];
    final query = state.query.trim();
    final displayItems = state.results;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        _SearchField(
          controller: _controller,
          hintText: state.defaultKeyword ?? '搜索歌曲、UP主，或粘贴 BV / 链接',
          onChanged: _scheduleSuggestions,
          onSubmitted: _submitSearch,
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s5),
                child: GestureDetector(
                  onTap: () {
                    final value = _controller.text.trim().isEmpty
                        ? state.query
                        : _controller.text;
                    ref
                        .read(searchProvider.notifier)
                        .search(value, mode: tabs[i].mode);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Column(
                      children: [
                        Text(
                          tabs[i].label,
                          style: AppTypography.body.copyWith(
                            color: tabs[i].mode == state.mode
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontWeight: tabs[i].mode == state.mode
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          width: 20,
                          color: tabs[i].mode == state.mode
                              ? colors.brand
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        if (state.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (query.isNotEmpty && state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
        if (query.isNotEmpty && state.suggestions.isNotEmpty) ...[
          SectionHeader(title: '搜索建议'),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s3,
            children: [
              for (final word in state.suggestions)
                _Chip(
                  label: word,
                  onTap: () {
                    _controller.text = word;
                    _controller.selection = TextSelection.collapsed(
                      offset: word.length,
                    );
                    _submitSearch(word);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (displayItems.isNotEmpty) ...[
          SectionHeader(
            title: state.mode == SearchMode.music ? '音乐结果' : '搜索结果',
          ),
          const SizedBox(height: AppSpacing.s2),
          for (int i = 0; i < displayItems.length; i++)
            TrackRow(
              index: i,
              track: displayItems[i],
              onLike: () => showAddToFavoriteDialog(context, displayItems[i]),
              onTap: () => play.playTrack(displayItems[i], queue: displayItems),
            ),
          if (state.hasMore || state.isLoadingMore) ...[
            const SizedBox(height: AppSpacing.s4),
            Center(
              child: OutlinedButton.icon(
                icon: state.isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(state.isLoadingMore ? '加载中' : '查看更多'),
                onPressed: state.isLoadingMore
                    ? null
                    : () => ref.read(searchProvider.notifier).loadMore(),
              ),
            ),
          ],
        ] else ...[
          SectionHeader(title: '热门搜索'),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s3,
            children: [
              for (final word in state.hotWords.take(12))
                _Chip(
                  label: word,
                  onTap: () {
                    _controller.text = word;
                    _controller.selection = TextSelection.collapsed(
                      offset: word.length,
                    );
                    _submitSearch(word);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          SectionHeader(title: '搜索历史'),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s3,
            children: [
              for (final word in state.history.take(8))
                _Chip(
                  label: word,
                  removable: true,
                  onTap: () {
                    _controller.text = word;
                    _controller.selection = TextSelection.collapsed(
                      offset: word.length,
                    );
                    _submitSearch(word);
                  },
                  onRemove: () =>
                      ref.read(searchProvider.notifier).removeHistory(word),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.bgHighlight,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.textTertiary, size: 22),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              cursorColor: colors.brand,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s3,
                ),
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: AppTypography.body.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.removable = false,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final bool removable;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            if (removable) ...[
              const SizedBox(width: AppSpacing.s2),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
