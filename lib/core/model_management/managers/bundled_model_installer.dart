part of '../../../mobile/flutter_gemma_mobile.dart';

/// Efficient installer for models bundled with the app
/// 
/// This installer:
/// 1. Checks if model is already installed (via SharedPreferences)
/// 2. Only copies from assets if not already present
/// 3. Registers model for use without downloading
/// 4. Supports multi-part files for large models (Android 2GB limit)
/// 
/// **Multi-part file support:**
/// For models larger than 2GB (Android asset limit), split the file into parts:
/// - `model.bin.part1`, `model.bin.part2`, etc.
/// - The installer auto-detects and assembles parts automatically
/// - Single files still work (backward compatible)
/// 
/// Usage:
/// ```dart
/// // Single file
/// await BundledModelInstaller.installIfNeeded(
///   InferenceModelSpec(
///     name: 'gemma-2b',
///     modelUrl: 'asset://assets/models/gemma-2b-it.bin',
///   ),
/// );
/// 
/// // Multi-part (auto-detected)
/// // Just reference the base filename, parts are auto-detected
/// await BundledModelInstaller.installIfNeeded(
///   InferenceModelSpec(
///     name: 'gemma-7b',
///     modelUrl: 'asset://assets/models/gemma-7b-it.bin',  // Parts: .bin.part1, .bin.part2...
///   ),
/// );
/// ```
class BundledModelInstaller {
  /// Installs a bundled model only if it's not already installed
  /// 
  /// This is much more efficient than reinstalling on every app launch
  static Future<void> installIfNeeded(ModelSpec spec) async {
    debugPrint('BundledModelInstaller: Checking if ${spec.name} needs installation');

    // Check if already installed
    if (await UnifiedDownloadEngine.isModelInstalled(spec)) {
      debugPrint('BundledModelInstaller: ${spec.name} already installed, skipping');
      return;
    }

    debugPrint('BundledModelInstaller: Installing ${spec.name} from assets');
    await _installBundledModel(spec);
  }

  /// Installs a bundled model from app assets
  static Future<void> _installBundledModel(ModelSpec spec) async {
    try {
      // Validate all URLs are asset URLs
      for (final file in spec.files) {
        final uri = Uri.parse(file.url);
        if (uri.scheme != 'asset') {
          throw ModelStorageException(
            'BundledModelInstaller only works with asset:// URLs, got: ${file.url}',
            null,
            'installBundledModel',
          );
        }
      }

      // Copy each file from assets to documents directory
      for (final file in spec.files) {
        final assetPath = Uri.parse(file.url).path; // Remove asset:// prefix
        final targetPath = await ModelFileSystemManager.getModelFilePath(file.filename);
        
        // Check if file already exists (might be from previous failed install)
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          final size = await targetFile.length();
          final minSize = file.extension == '.json' ? 1024 : 1024 * 1024;
          
          if (size >= minSize) {
            debugPrint('BundledModelInstaller: ${file.filename} already exists and is valid');
            continue;
          } else {
            debugPrint('BundledModelInstaller: ${file.filename} exists but is invalid, re-copying');
            await targetFile.delete();
          }
        }

        // Copy from assets
        await _copyFromAsset(assetPath, targetPath, file.filename);
      }

      // Register in SharedPreferences after ALL files are successfully copied
      await ModelPreferencesManager.saveModelFiles(spec);
      
      debugPrint('BundledModelInstaller: Successfully installed ${spec.name}');
    } catch (e) {
      // Cleanup partial installation
      for (final file in spec.files) {
        try {
          await ModelFileSystemManager.deleteModelFile(file.filename);
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      
      throw ModelStorageException(
        'Failed to install bundled model: ${spec.name}',
        e,
        'installBundledModel',
      );
    }
  }

  /// Copies a single file from Flutter assets to file system
  /// 
  /// Supports multi-part files (e.g., model.bin.part1, model.bin.part2)
  /// for models larger than Android's 2GB asset limit.
  /// 
  /// Auto-detects if part files exist and assembles them automatically.
  /// Falls back to single file copy if no parts are found.
  static Future<void> _copyFromAsset(
    String assetPath,
    String targetPath,
    String filename,
  ) async {
    try {
      debugPrint('BundledModelInstaller: Copying $assetPath -> $targetPath');
      
      // Try to detect multi-part files
      final parts = await _detectPartFiles(assetPath);
      
      if (parts.isNotEmpty) {
        // Multi-part file detected
        debugPrint('BundledModelInstaller: Detected ${parts.length} parts for $filename');
        await _assemblePartFiles(parts, targetPath, filename);
      } else {
        // Single file - use original logic
        debugPrint('BundledModelInstaller: Single file detected for $filename');
        await _copySingleFile(assetPath, targetPath);
      }
    } catch (e) {
      throw ModelStorageException(
        'Failed to copy asset: $assetPath',
        e,
        '_copyFromAsset',
      );
    }
  }

  /// Copies a single file from assets
  static Future<void> _copySingleFile(String assetPath, String targetPath) async {
    final assetData = await rootBundle.load(assetPath);
    final bytes = assetData.buffer.asUint8List();

    // Ensure target directory exists
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);

    // Write to target location
    await targetFile.writeAsBytes(bytes);

    debugPrint('BundledModelInstaller: Copied ${bytes.length} bytes to $targetPath');
  }

  /// Detects if multi-part files exist for the given asset path
  /// 
  /// Returns a list of part file paths in order (e.g., [path.part1, path.part2])
  /// Returns empty list if no parts are found
  static Future<List<String>> _detectPartFiles(String assetPath) async {
    final parts = <String>[];
    int partNumber = 1;
    
    // Try to find part files (e.g., model.bin.part1, model.bin.part2, etc.)
    while (true) {
      final partPath = '$assetPath.part$partNumber';
      try {
        // Try to load the part to see if it exists
        await rootBundle.load(partPath);
        parts.add(partPath);
        partNumber++;
      } catch (e) {
        // Part doesn't exist, stop searching
        break;
      }
    }
    
    return parts;
  }

  /// Assembles multiple part files into a single file
  static Future<void> _assemblePartFiles(
    List<String> partPaths,
    String targetPath,
    String filename,
  ) async {
    // Ensure target directory exists
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    
    // Open file for writing
    final sink = targetFile.openWrite();
    int totalBytes = 0;
    
    try {
      // Copy each part in order
      for (int i = 0; i < partPaths.length; i++) {
        final partPath = partPaths[i];
        debugPrint('BundledModelInstaller: Copying part ${i + 1}/${partPaths.length}: $partPath');
        
        final assetData = await rootBundle.load(partPath);
        final bytes = assetData.buffer.asUint8List();
        
        sink.add(bytes);
        totalBytes += bytes.length;
        
        debugPrint('BundledModelInstaller: Part ${i + 1} copied: ${bytes.length} bytes');
      }
      
      await sink.flush();
      await sink.close();
      
      debugPrint('BundledModelInstaller: Successfully assembled $filename from ${partPaths.length} parts');
      debugPrint('BundledModelInstaller: Total size: $totalBytes bytes (${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB)');
      
      // Verify the assembled file
      final assembledSize = await targetFile.length();
      if (assembledSize != totalBytes) {
        throw ModelStorageException(
          'File size mismatch after assembly. Expected: $totalBytes, Got: $assembledSize',
          null,
          '_assemblePartFiles',
        );
      }
    } catch (e) {
      // Clean up on error
      await sink.close();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      rethrow;
    }
  }

  /// Forces reinstallation of a bundled model (useful for updates)
  static Future<void> reinstall(ModelSpec spec) async {
    debugPrint('BundledModelInstaller: Force reinstalling ${spec.name}');
    
    // Delete existing installation
    try {
      await UnifiedDownloadEngine.deleteModel(spec);
    } catch (e) {
      debugPrint('BundledModelInstaller: No existing installation to delete');
    }
    
    // Install fresh
    await _installBundledModel(spec);
  }

  /// Checks if a bundled model is already installed
  static Future<bool> isInstalled(ModelSpec spec) async {
    return await UnifiedDownloadEngine.isModelInstalled(spec);
  }
}