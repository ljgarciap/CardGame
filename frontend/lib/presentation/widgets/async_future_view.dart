import 'package:flutter/material.dart';

import '../../core/errors/api_exception.dart';

/// Envuelve el boilerplate de loading/error/reintentar de un
/// `FutureBuilder` — antes duplicado igual en MyDecksPage, DeckBuilderPage,
/// MarketplacePage y GachaConfigAdminPage.
class AsyncFutureView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final String errorFallbackMessage;
  final Color? loadingColor;

  const AsyncFutureView({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    this.errorFallbackMessage = 'No se pudo cargar la información.',
    this.loadingColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: loadingColor));
        }
        if (snapshot.hasError) {
          final message = snapshot.error is ApiException
              ? (snapshot.error as ApiException).message
              : errorFallbackMessage;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}
