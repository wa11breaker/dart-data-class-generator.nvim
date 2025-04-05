class CollectionsModel {
  CollectionsModel({
    required this.id,
    required this.statusCodes,
    required this.childrenMap,
    required this.foo,
  });

  final int id;
  final Map<int, RequestModel> childrenMap;
  final List<int> statusCodes;
  final void Function(int) foo;
}
