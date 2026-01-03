import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:swim_apps_shared/repositories/invite_repository.dart';
import 'package:swim_apps_shared/repositories/user_repository.dart';

@GenerateNiceMocks([
  // Repositories
  MockSpec<InviteRepository>(),
  MockSpec<UserRepository>(),

  // Firebase
  MockSpec<FirebaseAuth>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<User>(),

  // Firestore references
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
  MockSpec<DocumentReference<Map<String, dynamic>>>(),

  // 🔑 REQUIRED FOR YOUR TESTS
  MockSpec<QuerySnapshot<Map<String, dynamic>>>(),
  MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(),
])
void main() {}
