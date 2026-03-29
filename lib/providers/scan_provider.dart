import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ocr_service.dart';
import '../services/gemini_service.dart';
import 'bill_provider.dart';
import 'participants_provider.dart';

/// Represents the current stage of the scan → parse pipeline.
enum ScanStage { idle, ocr, gemini, done, failed }

class ScanState {
  final ScanStage stage;
  final String? errorMessage;

  const ScanState({this.stage = ScanStage.idle, this.errorMessage});

  ScanState copyWith({ScanStage? stage, String? errorMessage}) =>
      ScanState(
        stage: stage ?? this.stage,
        errorMessage: errorMessage,
      );

  bool get isProcessing =>
      stage == ScanStage.ocr || stage == ScanStage.gemini;
}

/// Orchestrates the background OCR → Gemini → state-load pipeline.
///
/// Key design: this runs asynchronously. The UI navigates to BillReviewScreen
/// IMMEDIATELY after image capture. The user can add/select participants
/// while this pipeline runs in the background. When it completes, the items
/// and bill state are pushed into the existing providers, and the UI
/// rebuilds reactively via Riverpod watchers.
class ScanNotifier extends StateNotifier<ScanState> {
  final Ref _ref;

  ScanNotifier(this._ref) : super(const ScanState());

  /// Run the full pipeline: OCR → Gemini → load into providers.
  /// This is fire-and-forget from the UI's perspective.
  Future<void> processImage(String imagePath) async {
    // ── Stage 1: OCR ───────────────────────────────────────────
    state = const ScanState(stage: ScanStage.ocr);

    final ocrText = await OcrService.instance.recognizeText(imagePath);
    if (ocrText == null || ocrText.isEmpty) {
      state = const ScanState(
        stage: ScanStage.failed,
        errorMessage: 'Could not read text from the image.',
      );
      return;
    }

    // ── Stage 2: Gemini ────────────────────────────────────────
    state = const ScanState(stage: ScanStage.gemini);

    try {
      final result = await GeminiService.instance.parseOcrText(ocrText);

      // ── Stage 3: Load into providers ─────────────────────────
      final participantIds = _ref
          .read(participantsProvider)
          .map((p) => p.id)
          .toList();

      _ref.read(billItemsProvider.notifier).loadItems(
            result.items,
            participantIds,
          );
      _ref.read(billStateProvider.notifier).load(result.billState);

      state = const ScanState(stage: ScanStage.done);
    } on GeminiFailure catch (e) {
      state = ScanState(
        stage: ScanStage.failed,
        errorMessage: e.message,
      );
    } catch (e) {
      state = ScanState(
        stage: ScanStage.failed,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  void reset() => state = const ScanState();
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(ref),
);
