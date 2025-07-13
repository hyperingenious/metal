import 'package:appwrite/appwrite.dart';

final client = Client()
  ..setEndpoint('https://fra.cloud.appwrite.io/v1')
  ..setProject('685a8d7a001b583de71d')
  ..setSelfSigned(status: true)
  ..setDevKey(
    '60f0d597a14d8eb70e71879eb6aebdd76668a2f049f65fcda32401625065c18f2f1bcf576b38cf9dfcc5f70d172ba71da123ec5515b31662bacac60d16e8a63b6cb905912ead749d6281c5b09975872a903f22cc2a3820535d95b33b71df8da810a6ce53d987ca7fcb5494048e9a39520f0e94760c6777ce3e86587ddb085622',
  );

final account = Account(client);
final databases = Databases(client);
final storage = Storage(client);
