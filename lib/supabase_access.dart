import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';

// Supabase Client
SupabaseClient getSupabaseClient(supabaseUrl, supabaseKey) {
  return SupabaseClient(supabaseUrl, supabaseKey);
}
