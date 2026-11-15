/// 32-bit FNV-1a hash of [input].
///
/// Unlike `String.hashCode`, the result is guaranteed to be the same on every
/// run and platform, so it is safe to use as a persistent random seed (for
/// example to regenerate the same map for a saved city).
int stableHash(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
