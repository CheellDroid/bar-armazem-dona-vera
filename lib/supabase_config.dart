import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static Future<void> initialize() async {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw Exception('Configuração do Supabase não encontrada.');
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }
}
