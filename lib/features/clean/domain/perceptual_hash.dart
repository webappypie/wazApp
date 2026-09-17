// lib/features/clean/domain/perceptual_hash.dart
//
// 64-bit difference hash (dHash) and Hamming distance for perceptual similarity grouping (REQ-SIM-01).

import 'dart:typed_data';

class PerceptualHash {
  const PerceptualHash._();

  /// Computes a 64-bit dHash integer from a 9x8 row-major grayscale pixel array (72 bytes).
  ///
  /// For each row y from 0..7 and column x from 0..7:
  /// bit (y * 8 + x) is 1 if pixel(x, y) > pixel(x + 1, y), else 0.
  static int computeFromGrayscale9x8(Uint8List pixels) {
    assert(pixels.length >= 72, 'Grayscale buffer must have at least 72 bytes (9x8)');

    int hash = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final left = pixels[y * 9 + x];
        final right = pixels[y * 9 + (x + 1)];
        if (left > right) {
          hash |= (1 << (y * 8 + x));
        }
      }
    }
    return hash;
  }

  /// Calculates the Hamming distance between two 64-bit perceptual hashes.
  ///
  /// Returns the number of differing bit positions (0..64).
  /// A distance of 0 means identical visual fingerprint.
  /// A distance <= 10 typically indicates visually similar photos (burst shots, crops, slight edits).
  static int hammingDistance(int hashA, int hashB) {
    int xor = hashA ^ hashB;
    int count = 0;
    while (xor != 0) {
      count += xor & 1;
      // Logical right shift to handle 64-bit integer
      xor = (xor >> 1) & 0x7FFFFFFFFFFFFFFF;
    }
    return count;
  }

  /// Groups items by pairwise similarity where Hamming distance <= [threshold].
  ///
  /// Returns clusters of item IDs that are visually similar.
  static List<List<T>> clusterSimilar<T>({
    required List<T> items,
    required int Function(T item) hashSelector,
    int threshold = 10,
  }) {
    final visited = <int>{};
    final clusters = <List<T>>[];

    for (int i = 0; i < items.length; i++) {
      if (visited.contains(i)) continue;

      final currentCluster = <T>[items[i]];
      visited.add(i);

      final hashA = hashSelector(items[i]);

      for (int j = i + 1; j < items.length; j++) {
        if (visited.contains(j)) continue;

        final hashB = hashSelector(items[j]);
        if (hammingDistance(hashA, hashB) <= threshold) {
          currentCluster.add(items[j]);
          visited.add(j);
        }
      }

      // Only groups with 2 or more items constitute a similarity cluster
      if (currentCluster.length > 1) {
        clusters.add(currentCluster);
      }
    }

    return clusters;
  }
}
