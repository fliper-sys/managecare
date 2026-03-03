class Worker {
  final String id;
  final String name;
  final String role;
  final String email;

  Worker(
      {required this.id,
      required this.name,
      required this.role,
      this.email = ''});
}

