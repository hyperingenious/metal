import 'package:appwrite/appwrite.dart';

final client = Client()
  ..setEndpoint('https://fra.cloud.appwrite.io/v1')
  ..setProject('685a8d7a001b583de71d')
  ..setSelfSigned(status: true);

final account = Account(client);