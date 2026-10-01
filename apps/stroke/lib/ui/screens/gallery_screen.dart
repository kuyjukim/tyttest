import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../data/sketch_repository.dart';
import '../../state/studio_store.dart';
import '../strings.dart';

/// Every sketch on the device.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<StudioStore>(context);
    final strings = S.of(context);

    return PaperScaffold(
      title: strings.appName,
      actions: [
        PaperIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: strings.about,
          onPressed: () => showPaperSheet<void>(
            context: context,
            title: strings.about,
            builder: (context) => Padding(
              padding: const EdgeInsets.only(bottom: Gap.lg),
              child: Text(strings.aboutBody, style: context.type.body),
            ),
          ),
        ),
        const SizedBox(width: Gap.xs),
      ],
      body: Column(
        children: [
          Expanded(
            child: store.gallery.isEmpty
                ? EmptyState(
                    icon: Icons.draw_outlined,
                    title: strings.galleryEmptyTitle,
                    message: strings.galleryEmptyBody,
                    actionLabel: strings.newSketch,
                    onAction: store.createSketch,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(
                      top: Gap.lg,
                      bottom: Gap.lg,
                    ),
                    itemCount: store.gallery.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                    itemBuilder: (context, index) => _SketchRow(
                      summary: store.gallery[index],
                      strings: strings,
                      onOpen: () => store.openSketch(store.gallery[index].id),
                      onDelete: () => _confirmDelete(
                        context,
                        store,
                        strings,
                        store.gallery[index],
                      ),
                    ),
                  ),
          ),
          if (store.gallery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.lg, top: Gap.sm),
              child: PaperButton(
                label: strings.newSketch,
                icon: Icons.add_rounded,
                size: PaperButtonSize.large,
                expand: true,
                onPressed: store.createSketch,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    StudioStore store,
    S strings,
    SketchSummary summary,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.deleteSketchTitle,
      message: strings.deleteSketchBody,
      confirmLabel: strings.deleteSketchAction,
    );
    if (!confirmed) return;
    await store.deleteSketch(summary.id);
  }
}

class _SketchRow extends StatelessWidget {
  const _SketchRow({
    required this.summary,
    required this.strings,
    required this.onOpen,
    required this.onDelete,
  });

  final SketchSummary summary;
  final S strings;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = summary.name.trim().isEmpty ? strings.untitled : summary.name;
    return PaperCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 36,
            decoration: BoxDecoration(
              color: context.colors.surfaceSunken,
              borderRadius: Radii.allXs,
              border: Border.all(color: context.colors.hairline),
            ),
            child: Icon(
              Icons.draw_outlined,
              size: 18,
              color: context.colors.inkFaint,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodyStrong,
                ),
                const SizedBox(height: Gap.xxs),
                Text(
                  '${strings.strokeCount(summary.strokeCount)} · '
                  '${DateFormat.yMMMd().add_jm().format(summary.updatedAt)}',
                  style: context.type.caption,
                ),
              ],
            ),
          ),
          PaperIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: strings.delete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
