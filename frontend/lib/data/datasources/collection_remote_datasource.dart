import 'base_remote_datasource.dart';

class CollectionRemoteDatasource extends BaseRemoteDatasource {
  CollectionRemoteDatasource({super.client});

  Future<List<dynamic>> getMyCards({required String token}) async {
    final response = await client.get(
      uri('/api/cards/mine'),
      headers: authHeaders(token),
    );
    return decodeListOrThrow(response);
  }
}
