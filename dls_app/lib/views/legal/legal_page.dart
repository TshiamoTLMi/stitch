import 'package:flutter/material.dart';

import '../../core/legal/legal_content.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.type});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final sections = LegalContent.sectionsFor(type);
    return Scaffold(
      appBar: AppBar(title: Text(LegalContent.titleFor(type))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            LegalContent.titleFor(type),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (type == LegalDocumentType.privacy) ...[
            const SizedBox(height: 4),
            SelectableText(
              'Web version: ${LegalConfig.privacyPolicyUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          for (final section in sections) ...[
            Text(
              section.heading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(paragraph),
              ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
