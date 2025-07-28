import 'package:appwrite/appwrite.dart';

final client = Client()
  ..setEndpoint('https://fra.cloud.appwrite.io/v1')
  ..setProject('685a8d7a001b583de71d')
  ..setSelfSigned(status: true)
..setDevKey(
'706cc3b4fb12ca530f33f3a684be1db814cbc2ee3240ae7cf9d322c2733fe8d4add5bc84f576f15f1f6ce009cf0949b496633b288c33553c527fece4956ca3388b4b11ce96557ea8f64190f36138dce0427d9d5fc2af5d8e7986b828ee9950b23596a03fd4766750778d8d73b6330c69146d9551c1d0ec7d44786d43f1946f19',
);

final account = Account(client);
final databases = Databases(client);
final storage = Storage(client);
final realtime = Realtime(client);