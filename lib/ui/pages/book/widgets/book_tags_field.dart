import 'package:flutter/material.dart';
import 'package:read_stats/data/models/tag.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';

/// The book form's tags: a "Tags" row with the chosen tags as chips under
/// it, opening the tag selector.
class BookTagsField extends StatelessWidget {
  final Set<int> tagIds;
  final VoidCallback onTap;

  const BookTagsField({super.key, required this.tagIds, required this.onTap});

  Future<List<Tag>> _tags() async {
    if (tagIds.isEmpty) return [];
    final allTags = await TagRepository().getAllTags();
    return allTags.where((tag) => tagIds.contains(tag.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sell,
                  size: 18,
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tags',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (tagIds.isNotEmpty)
              FutureBuilder<List<Tag>>(
                future: _tags(),
                builder: (context, snapshot) {
                  final tags = snapshot.data ?? [];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: tags.isEmpty
                        ? const SizedBox.shrink()
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tag.name,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
