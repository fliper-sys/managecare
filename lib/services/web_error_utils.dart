String describeWebError(Object? error) {
  if (error == null) return 'unknown error';
  if (error is Error) return error.toString();
  return error.toString();
}
