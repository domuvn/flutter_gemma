part of '../../../mobile/flutter_gemma_mobile.dart';

/// Efficient installer for models bundled with the app
/// 
/// This installer:
/// 1. Checks if model is already installed (via SharedPreferences)
/// 2. Only copies from assets if not already present
/// 3. Registers model for use without downloading
/// 
/// Usage:
/// ```dart
/// await BundledModelInstaller.installIfNeeded(
///   InferenceModelSpec(
///     name: 'gemma-2b',
///     modelUrl: 'asset://assets/models/gemma-2b-it.bin',
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
  static Future<void> _copyFromAsset(
    String assetPath,
    String targetPath,
    String filename,
  ) async {
    try {
      debugPrint('BundledModelInstaller: Copying $assetPath -> $targetPath');
      
      // Load asset data
      final assetData = await rootBundle.load(assetPath);
      final bytes = assetData.buffer.asUint8List();

      // Ensure target directory exists
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);

      // Write to target location
      await targetFile.writeAsBytes(bytes);

      debugPrint('BundledModelInstaller: Copied ${bytes.length} bytes to $targetPath');
    } catch (e) {
      throw ModelStorageException(
        'Failed to copy asset: $assetPath',
        e,
        '_copyFromAsset',
      );
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