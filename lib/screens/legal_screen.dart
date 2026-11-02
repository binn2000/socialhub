import 'package:flutter/material.dart';
import 'package:flutter_learning/data/legal_texts.dart';

class LegalScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (heading, body) in document.sections) ...[
            Text(
              heading,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: textTheme.bodyMedium),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

void openLegal(BuildContext context, LegalDocument document) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LegalScreen(document: document)),
  );
}
