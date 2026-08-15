class MeluneAccount {
  const MeluneAccount({
    required this.id,
    required this.name,
    this.face = '',
    this.mid = 0,
  });

  final String id;
  final String name;
  final String face;
  final int mid;
}
