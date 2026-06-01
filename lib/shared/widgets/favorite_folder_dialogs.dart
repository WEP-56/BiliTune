import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import 'app_toast.dart';
import '../../state/providers.dart';

Future<void> showCreateFavoriteFolderDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CreateFavoriteFolderDialog(),
  );
}

Future<bool?> showAddToFavoriteDialog(BuildContext context, Track track) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _AddToFavoriteDialog(track: track),
  );
}

class _CreateFavoriteFolderDialog extends ConsumerStatefulWidget {
  const _CreateFavoriteFolderDialog();

  @override
  ConsumerState<_CreateFavoriteFolderDialog> createState() =>
      _CreateFavoriteFolderDialogState();
}

class _CreateFavoriteFolderDialogState
    extends ConsumerState<_CreateFavoriteFolderDialog> {
  final _titleController = TextEditingController();
  final _introController = TextEditingController();
  bool _isPrivate = false;

  @override
  void dispose() {
    _titleController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);

    return Dialog(
      backgroundColor: colors.bgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '新建收藏夹',
                style: AppTypography.titleM.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: _titleController,
                autofocus: true,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
                decoration: _inputDecoration(colors, '收藏夹标题'),
              ),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                controller: _introController,
                minLines: 2,
                maxLines: 3,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
                decoration: _inputDecoration(colors, '简介，可留空'),
              ),
              const SizedBox(height: AppSpacing.s3),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPrivate,
                activeColor: colors.brand,
                onChanged: (value) =>
                    setState(() => _isPrivate = value ?? false),
                title: Text(
                  '设为私密收藏夹',
                  style: AppTypography.body.copyWith(color: colors.textPrimary),
                ),
              ),
              if (library.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  library.errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: library.isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: FilledButton(
                      onPressed: !auth.isSignedIn || library.isLoading
                          ? null
                          : _submit,
                      child: library.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('创建'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BiliColors colors, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.caption.copyWith(color: colors.textTertiary),
      filled: true,
      fillColor: colors.bgHighlight,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submit() async {
    await ref
        .read(libraryProvider.notifier)
        .createFavoriteFolder(
          title: _titleController.text,
          intro: _introController.text,
          isPrivate: _isPrivate,
        );
    if (!mounted) return;
    if (ref.read(libraryProvider).errorMessage == null) {
      Navigator.of(context).pop(true);
    }
  }
}

class _AddToFavoriteDialog extends ConsumerWidget {
  const _AddToFavoriteDialog({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);

    return Dialog(
      backgroundColor: colors.bgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '添加到收藏夹',
                      style: AppTypography.titleM.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              if (!auth.isSignedIn)
                Text(
                  '需要先登录 Bilibili 账号。',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else if (library.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (library.folders.isEmpty)
                Text(
                  '还没有可用收藏夹，可以先新建一个。',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: library.folders.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.bgHighlight),
                    itemBuilder: (_, index) {
                      final folder = library.folders[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          folder.isPublic
                              ? Icons.folder_outlined
                              : Icons.lock_outline_rounded,
                          color: colors.textSecondary,
                        ),
                        title: Text(
                          folder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${folder.mediaCount} 首',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                        onTap: () => _add(context, ref, folder),
                      );
                    },
                  ),
                ),
              if (library.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s3),
                Text(
                  library.errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('新建收藏夹'),
                  onPressed: auth.isSignedIn
                      ? () => showCreateFavoriteFolderDialog(context)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    BiliFavoriteFolder folder,
  ) async {
    try {
      await ref
          .read(libraryProvider.notifier)
          .addTrackToFavoriteFolder(track, folder.mediaId);
      if (!context.mounted) return;
      final colors = context.colors;
      showAppToast(
        context,
        message: '已添加到 ${folder.title}',
        icon: Icons.favorite_rounded,
        accentColor: colors.brand,
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      // Error text is surfaced by LibraryState in the dialog.
    }
  }
}
