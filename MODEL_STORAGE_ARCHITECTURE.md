# Model Storage & Linking Architecture

## 📋 Summary: How Models are Stored and Linked

### After `downloadModelFromNetwork()` or Asset Installation

```
┌─────────────────────────────────────────────────────────────┐
│                    DOWNLOAD/INSTALL PHASE                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  1. PHYSICAL STORAGE (File System)                          │
│                                                               │
│  Location: getApplicationDocumentsDirectory()                │
│                                                               │
│  Android: /data/data/[package]/files/                       │
│  iOS: ~/Library/Application Support/                         │
│                                                               │
│  Files:                                                       │
│  ├─ model.bin          (Inference model)                     │
│  ├─ lora.task          (LoRA weights, optional)             │
│  ├─ embeddings.tflite  (Embedding model)                    │
│  └─ tokenizer.json     (Tokenizer)                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  2. REGISTRATION (SharedPreferences)                         │
│                                                               │
│  Keys:                                                        │
│  ├─ "installed_models": ["model.bin", "model2.bin"]        │
│  ├─ "installed_loras": ["lora.task"]                       │
│  ├─ "installed_embedding_models": ["embeddings.tflite"]    │
│  └─ "installed_tokenizers": ["tokenizer.json"]             │
│                                                               │
│  Purpose: Track what's installed, enable multi-model        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  3. MODEL READY (Available for Loading)                     │
└─────────────────────────────────────────────────────────────┘




┌─────────────────────────────────────────────────────────────┐
│                      LINKING/LOADING PHASE                   │
│                  (When createModel() is called)              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  4. QUERY REGISTRY (UnifiedModelManager)                    │
│                                                               │
│  manager.currentActiveModel                                  │
│      ↓                                                        │
│  Check SharedPreferences for installed models               │
│      ↓                                                        │
│  Verify model files exist and are valid                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  5. RESOLVE PATHS (ModelFileSystemManager)                  │
│                                                               │
│  filename: "model.bin"                                       │
│      ↓                                                        │
│  getModelFilePath("model.bin")                              │
│      ↓                                                        │
│  full path: "/data/data/[package]/files/model.bin"         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  6. LOAD INTO NATIVE (Platform Channel)                     │
│                                                               │
│  Dart: _platformService.createModel(modelPath: ...)        │
│      ↓                                                        │
│  Android: LlmInference.createFromOptions()                  │
│  iOS: LlmInference(options: modelPath)                      │
│      ↓                                                        │
│  MediaPipe loads model into memory                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  7. MODEL READY FOR INFERENCE                               │
│                                                               │
│  InferenceModel → createSession() → getResponse()           │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Two Installation Methods Comparison

### Method 1: Network Download (Existing)
```
User triggers download
     ↓
downloadModelFromNetwork(url)
     ↓
[Background Downloader]
     ↓
Stream<bytes> → File in /data/data/.../
     ↓
Validate file size/integrity
     ↓
Register in SharedPreferences
     ↓
READY
```

**Pros:** Model updates without app update
**Cons:** Requires network, first-time wait

---

### Method 2: Bundled Assets (NEW!)
```
App installed with model in assets/
     ↓
First launch: BundledModelInstaller.installIfNeeded()
     ↓
Check SharedPreferences: already installed?
     ↓ NO
Copy asset → /data/data/.../
     ↓
Register in SharedPreferences
     ↓
READY

Subsequent launches:
     ↓ YES
Skip copy, already registered
     ↓
READY (instant!)
```

**Pros:** Offline, instant availability, one-time copy
**Cons:** Larger app size, harder to update

---

## 🎯 Can You Skip the Copy?

### ❌ No, because:

1. **MediaPipe Native APIs** require:
   ```kotlin
   // Android
   File(config.modelPath).exists()  // Needs real filesystem path
   ```
   ```swift
   // iOS
   LlmInference.Options(modelPath: resolvedPath)  // Needs file:// path
   ```

2. **Flutter Assets** are:
   - Embedded in app bundle
   - Accessed via `rootBundle.load()`
   - Not directly accessible to native code
   - Can't be passed as file paths

### ✅ But You Can Optimize:

1. **Copy only once** (checked via SharedPreferences)
2. **Register filename** in SharedPreferences
3. **Resolve to full path** when needed
4. **Reuse** on every app launch without re-copying

---

## 💾 Storage Locations

### Asset Models (Bundled)
```
Before Installation:
  App Bundle (read-only)
  └─ assets/models/model.bin

After Installation:
  App Bundle (unused after copy)
  └─ assets/models/model.bin
  
  Documents Directory (used)
  └─ /data/data/[package]/files/model.bin
  
  SharedPreferences
  └─ "installed_models": ["model.bin"]
```

### Downloaded Models
```
After Download:
  Documents Directory
  └─ /data/data/[package]/files/model.bin
  
  SharedPreferences
  └─ "installed_models": ["model.bin"]
```

**Both end up in the same place!**

---

## 🔗 Linking Flow

```dart
// You call:
FlutterGemmaPlugin.instance.createModel(...)

// Internally:
1. manager.currentActiveModel
       ↓
2. manager.isModelInstalled(spec)
       ↓ checks SharedPreferences
3. manager.getModelFilePaths(spec)
       ↓ reads SharedPreferences
4. ModelFileSystemManager.getModelFilePath(filename)
       ↓ resolves to full path
5. _platformService.createModel(modelPath: fullPath)
       ↓ native code loads model
6. Returns MobileInferenceModel ready for use
```

---

## 📊 File Organization Example

```
/data/data/com.example.app/files/
├── gemma-2b-it.bin           (1.5GB - Inference model)
├── gemma-7b-it.bin           (4GB - Another model)
├── lora-weights.task         (100MB - LoRA weights)
├── universal-sentence.tflite (50MB - Embedding model)
└── tokenizer.json            (500KB - Tokenizer)

SharedPreferences:
{
  "installed_models": [
    "gemma-2b-it.bin",
    "gemma-7b-it.bin"
  ],
  "installed_loras": [
    "lora-weights.task"
  ],
  "installed_embedding_models": [
    "universal-sentence.tflite"
  ],
  "installed_tokenizers": [
    "tokenizer.json"
  ]
}
```

---

## 🎓 Key Takeaways

1. **Storage**: Always in app documents directory
2. **Registration**: Always in SharedPreferences
3. **Linking**: Runtime path resolution via filename lookup
4. **Assets**: Must be copied once, then reused
5. **Downloads**: Direct to documents directory
6. **Native APIs**: Require filesystem paths, not asset URLs
7. **Efficiency**: SharedPreferences prevents redundant copying

---

## 🚀 Best Practice

```dart
// On app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Install bundled model (efficient, one-time copy)
  await BundledModelInstaller.installIfNeeded(
    InferenceModelSpec(
      name: 'my-bundled-model',
      modelUrl: 'asset://assets/models/model.bin',
    ),
  );
  
  runApp(MyApp());
}

// Later, use normally
final model = await FlutterGemmaPlugin.instance.createModel(
  modelType: ModelType.gemmaIt,
);

// Model is loaded from:
// /data/data/[package]/files/model.bin
// (Not from assets!)
```
