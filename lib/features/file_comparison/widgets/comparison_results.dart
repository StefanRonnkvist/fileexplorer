import 'package:flutter/material.dart';

import '../controllers/comparison_controller.dart';
import '../models/comparison_entry.dart';

/// Lists the distinct file contents of the current comparison.
class ComparisonResults extends StatelessWidget {
  const ComparisonResults({super.key, required this.comparison});

  final ComparisonController comparison;

  @override
  Widget build(BuildContext context) {
    if (comparison.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (comparison.entries.isEmpty) {
      return const Center(
        child: Text('Expand a file group and select Compare.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: comparison.entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _EntryCard(entry: comparison.entries[index], index: index),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.index});

  final ComparisonEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 96,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    entry.paths.join('\n'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  key: ValueKey<String>('comparison-horizontal-scroll-$index'),
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    entry.content,
                    key: ValueKey<String>('comparison-content-$index'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
