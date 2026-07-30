class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _cache = {};

  /// Retrieves data from cache if it exists and hasn't expired
  T? get<T>(String key) {
    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (!entry.isExpired()) {
        return entry.data as T;
      } else {
        _cache.remove(key); // Evict expired
      }
    }
    return null;
  }

  /// Saves data to cache with a specified time-to-live (TTL)
  void set(String key, dynamic data, {Duration ttl = const Duration(minutes: 5)}) {
    _cache[key] = _CacheEntry(
      data: data,
      expiryTime: DateTime.now().add(ttl),
    );
  }

  /// Check if cache has a valid entry
  bool hasValid(String key) {
    if (_cache.containsKey(key)) {
      if (!_cache[key]!.isExpired()) return true;
      _cache.remove(key);
    }
    return false;
  }

  /// Removes an item from the cache
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Clears the entire cache
  void clear() {
    _cache.clear();
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiryTime;

  _CacheEntry({required this.data, required this.expiryTime});

  bool isExpired() => DateTime.now().isAfter(expiryTime);
}
