import '../domain/feedback_submission.dart';

abstract interface class FeedbackGateway {
  bool get isConfigured;

  Future<void> submit(FeedbackSubmission submission);
}
