import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'policy_models.dart';
import 'policy_repository.dart';

class PolicyGateController extends ChangeNotifier {
  PolicyGateController({
    required PolicyRepository repository,
    required String uid,
    required String appId,
    this.contextKey = 'default',
  }) : _repository = repository,
       _uid = uid.trim(),
       _appId = appId.trim();

  final PolicyRepository _repository;
  final String _uid;
  final String _appId;
  final String contextKey;

  PolicyGateDecision? decision;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;
  bool termsChecked = false;
  bool privacyChecked = false;

  bool get canContinue => termsChecked && privacyChecked && !isSubmitting;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      decision = await _repository.checkAccess(
        uid: _uid,
        appId: _appId,
        contextKey: contextKey,
      );
      termsChecked = decision?.termsAccepted == true;
      privacyChecked = decision?.privacyAccepted == true;
    } catch (error) {
      errorMessage = 'Could not load legal policies.';
      debugPrint('PolicyGate load failed: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openTerms() async {
    await _openUrl(decision?.bundle.terms.url ?? '');
  }

  Future<void> openPrivacy() async {
    await _openUrl(decision?.bundle.privacy.url ?? '');
  }

  void setTermsChecked(bool value) {
    termsChecked = value;
    notifyListeners();
  }

  void setPrivacyChecked(bool value) {
    privacyChecked = value;
    notifyListeners();
  }

  Future<bool> acceptAndContinue() async {
    final current = decision;
    if (current == null || !canContinue) return false;

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.acceptCurrentBundle(
        appId: current.bundle.appId,
        contextKey: current.bundle.contextKey,
        termsVersion: current.bundle.terms.version,
        privacyVersion: current.bundle.privacy.version,
      );
      decision = await _repository.checkAccess(
        uid: _uid,
        appId: _appId,
        contextKey: contextKey,
      );
      return decision?.requiresAcceptance != true;
    } catch (error) {
      errorMessage = 'Could not save policy acceptance. Please try again.';
      debugPrint('PolicyGate acceptance failed: $error');
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _openUrl(String rawUrl) async {
    final parsed = Uri.tryParse(rawUrl.trim());
    if (parsed == null) {
      errorMessage = 'Policy link is unavailable right now.';
      notifyListeners();
      return;
    }

    final opened = await launchUrl(parsed, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      errorMessage = 'Could not open policy link.';
      notifyListeners();
    }
  }
}

class PolicyGatePage extends StatefulWidget {
  const PolicyGatePage({
    super.key,
    required this.repository,
    required this.uid,
    required this.appId,
    this.contextKey = 'default',
    required this.onAccepted,
    this.title = 'Updated legal policies',
    this.subtitle =
        'Please review and accept the latest Terms and Privacy Policy to continue.',
  });

  final PolicyRepository repository;
  final String uid;
  final String appId;
  final String contextKey;
  final FutureOr<void> Function() onAccepted;
  final String title;
  final String subtitle;

  @override
  State<PolicyGatePage> createState() => _PolicyGatePageState();
}

class _PolicyGatePageState extends State<PolicyGatePage> {
  late final PolicyGateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PolicyGateController(
      repository: widget.repository,
      uid: widget.uid,
      appId: widget.appId,
      contextKey: widget.contextKey,
    )..addListener(_onControllerChange);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChange)
      ..dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final decision = _controller.decision;
    if (decision == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Legal policies')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _controller.errorMessage ?? 'Could not load legal policies.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Legal policies')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(widget.subtitle),
            const SizedBox(height: 24),
            _PolicyItem(
              title: 'Terms and Conditions',
              version: decision.bundle.terms.version,
              checked: _controller.termsChecked,
              onOpen: _controller.openTerms,
              onChanged: _controller.setTermsChecked,
            ),
            const SizedBox(height: 12),
            _PolicyItem(
              title: 'Privacy Policy',
              version: decision.bundle.privacy.version,
              checked: _controller.privacyChecked,
              onOpen: _controller.openPrivacy,
              onChanged: _controller.setPrivacyChecked,
            ),
            const Spacer(),
            if ((_controller.errorMessage ?? '').isNotEmpty) ...[
              Text(
                _controller.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _controller.canContinue
                    ? () async {
                        final accepted = await _controller.acceptAndContinue();
                        if (accepted && mounted) {
                          await widget.onAccepted();
                        }
                      }
                    : null,
                child: _controller.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Agree and continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  const _PolicyItem({
    required this.title,
    required this.version,
    required this.checked,
    required this.onOpen,
    required this.onChanged,
  });

  final String title;
  final String version;
  final bool checked;
  final Future<void> Function() onOpen;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Version: $version'),
                ],
              ),
            ),
            TextButton(onPressed: onOpen, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}
