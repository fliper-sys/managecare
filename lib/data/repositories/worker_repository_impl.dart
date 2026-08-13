import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'worker_repository_supabase.dart';

class WorkerRepositoryImpl extends WorkerRepositorySupabase {
  WorkerRepositoryImpl({
    FirebaseFirestore? firestore,
    Dio? http,
    SupabaseClient? supabase,
  }) : super(http: http, supabase: supabase);
}
