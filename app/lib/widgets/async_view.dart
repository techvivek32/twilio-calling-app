import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';

/// Loads [load] once, then rebuilds through [builder]. Shows a spinner while
/// in flight and the server's own message on failure, with a retry button.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.padding = const EdgeInsets.all(AppSpace.xl),
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload)
  builder;
  final EdgeInsetsGeometry padding;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  Future<void> reload() async {
    // A block body, not an arrow: an arrow returns the assigned Future and
    // setState rejects a callback that returns one.
    setState(() {
      _future = widget.load();
    });
    await _future.catchError((Object error) => throw error);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.xxl),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return ErrorPanel(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _future = widget.load();
            }),
            padding: widget.padding,
          );
        }

        return widget.builder(
          context,
          snapshot.data as T,
          () async => setState(() {
            _future = widget.load();
          }),
        );
      },
    );
  }
}

/// Friendly failure state that surfaces the server's message verbatim.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.error,
    required this.onRetry,
    this.padding = const EdgeInsets.all(AppSpace.xl),
  });

  final Object error;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final isSetup = api?.isConfigurationIssue ?? false;

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isSetup ? AppColors.primarySoft : AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSetup ? Icons.settings_outlined : Icons.cloud_off,
                size: 32,
                color: isSetup ? AppColors.primary : AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              isSetup ? 'Setup needed' : 'Could not load',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              api?.message ?? error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(180, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown where a screen needs a Twilio number the admin has not granted yet.
class NoNumberPanel extends StatelessWidget {
  const NoNumberPanel({super.key, this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_disabled_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              'No number assigned',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'Your administrator has not given this account a Twilio number '
              'yet. Calls and messages unlock as soon as they do.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpace.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
