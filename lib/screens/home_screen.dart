import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../providers/providers.dart';
import '../services/permission_service.dart';
import '../services/recent_contacts_service.dart';
import 'bill_review_screen.dart';
import 'quick_split_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadSavedUpiId();
  }

  /// Load the payer's UPI ID from shared_preferences on startup.
  Future<void> _loadSavedUpiId() async {
    final saved = await RecentContactsService.instance.loadPayerUpiId();
    if (saved != null && saved.isNotEmpty && mounted) {
      ref.read(payerUpiIdProvider.notifier).state = saved;
    }
  }

  Future<void> _scanBill() async {
    // Request camera permission before launching
    final granted = await PermissionService.instance.requestCamera();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan bills.'),
        ),
      );
      return;
    }

    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;
    _startScanFlow(image.path);
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;
    _startScanFlow(image.path);
  }

  /// Core parallel-execution flow:
  /// 1. Set up payer + reset state.
  /// 2. Navigate to BillReviewScreen IMMEDIATELY (user can add participants).
  /// 3. Fire OCR → Gemini pipeline in the BACKGROUND.
  void _startScanFlow(String imagePath) {
    _setupPayer();

    ref.read(scanProvider.notifier).reset();
    ref.read(billItemsProvider.notifier).clear();
    ref.read(billStateProvider.notifier).clear();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillReviewScreen(imagePath: imagePath),
      ),
    );

    // Fire background processing (non-blocking)
    ref.read(scanProvider.notifier).processImage(imagePath);
  }

  void _goQuickSplit() {
    _setupPayer();
    ref.read(billItemsProvider.notifier).clear();
    ref.read(billStateProvider.notifier).clear();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuickSplitScreen()),
    );
  }

  void _setupPayer() {
    final payerId = ref.read(payerIdProvider);
    if (payerId == null) {
      final id = _uuid.v4();
      ref.read(participantsProvider.notifier).add(id, 'You');
      ref.read(payerIdProvider.notifier).state = id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Icon(
                Icons.receipt_long_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'SplitFast',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bill arrives. Everyone pays. Under 45 seconds.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _scanBill,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text(
                    'Scan Bill',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text(
                    'Pick from Gallery',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.tonalIcon(
                  onPressed: _goQuickSplit,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text(
                    'Quick Split',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
