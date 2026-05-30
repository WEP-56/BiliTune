import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/mock/mock_data.dart';

/// Search page (design doc §6.3): search field, category tabs, hot words and
/// recent searches. Input is non-functional in M0 (real search lands in M2).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= AppLayout.desktopBreakpoint ? AppSpacing.s6 : AppSpacing.s4;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        _SearchField(),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            for (int i = 0; i < MockData.searchTabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s5),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Column(
                      children: [
                        Text(
                          MockData.searchTabs[i],
                          style: AppTypography.body.copyWith(
                            color: i == _tab
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontWeight:
                                i == _tab ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          width: 20,
                          color: i == _tab ? colors.brand : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text('热门搜索',
            style: AppTypography.titleM.copyWith(color: colors.textPrimary)),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          spacing: AppSpacing.s3,
          runSpacing: AppSpacing.s3,
          children: [
            for (final word in MockData.hotWords) _Chip(label: word),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text('搜索历史',
            style: AppTypography.titleM.copyWith(color: colors.textPrimary)),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          spacing: AppSpacing.s3,
          runSpacing: AppSpacing.s3,
          children: [
            for (final word in MockData.hotWords.take(4))
              _Chip(label: word, removable: true),
          ],
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
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
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              cursorColor: colors.brand,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                border: InputBorder.none,
                hintText: '搜索歌曲、UP主，或粘贴 BV / 链接',
                hintStyle: AppTypography.body
                    .copyWith(color: colors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.removable = false});

  final String label;
  final bool removable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  AppTypography.body.copyWith(color: colors.textSecondary)),
          if (removable) ...[
            const SizedBox(width: AppSpacing.s2),
            Icon(Icons.close_rounded, size: 14, color: colors.textTertiary),
          ],
        ],
      ),
    );
  }
}
