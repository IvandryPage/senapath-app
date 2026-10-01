import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feedback_submission.dart';
import 'feedback_gateway.dart';

class SupabaseFeedbackGateway implements FeedbackGateway {
  const SupabaseFeedbackGateway(this._client);

  final SupabaseClient? _client;

  @override
  bool get isConfigured => _client != null;

  @override
  Future<void> submit(FeedbackSubmission submission) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    if (client.auth.currentUser == null) {
      throw StateError('Masuk ke akun online sebelum mengirim feedback.');
    }

    final response = await client.functions.invoke(
      'submit-feedback',
      body: {
        'consent': true,
        'submissionId': submission.id,
        'message': submission.message,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Feedback belum terkirim.');
    }
  }
}
