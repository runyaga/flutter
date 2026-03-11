import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Plugin exposing sandboxed local file system operations to Monty scripts.
///
/// Functions are named after familiar Linux commands (`cat`, `ls`, `mkdir`,
/// `rm`, `stat`, `find`). All paths are resolved relative to `rootPath`
/// and validated to prevent path traversal. Symlinks are resolved before
/// the containment check.
class LocalFsPlugin extends MontyPlugin {
  /// Creates a [LocalFsPlugin] rooted at [rootPath].
  ///
  /// Throws [ArgumentError] if [rootPath] does not exist or is not a
  /// directory.
  LocalFsPlugin({required String rootPath})
      : _rootPath = Directory(rootPath).resolveSymbolicLinksSync();

  final String _rootPath;

  @override
  String get namespace => 'fs';

  @override
  String? get systemPromptContext =>
      'Read and write local files within the sandbox root. '
      'Commands mirror Linux: cat, ls, write, mkdir, rm, stat, '
      'exists, find.';

  @override
  String get pythonPrelude => '''
def cat(path):
    return fs_cat(path=path)
_help_docs[cat] = "Read a UTF-8 text file. Usage: cat(path)"

def ls(path=".", recursive=False):
    return fs_ls(path=path, recursive=recursive)
_help_docs[ls] = "List directory entries. Usage: ls(path, recursive=False)"

def write(path, content):
    fs_write(path=path, content=content)
_help_docs[write] = "Write text to a file. Usage: write(path, content)"

def mkdir(path):
    fs_mkdir(path=path)
_help_docs[mkdir] = "Create directory (recursive). Usage: mkdir(path)"

def rm(path):
    fs_rm(path=path)
_help_docs[rm] = "Delete a file or empty directory. Usage: rm(path)"

def stat(path):
    return fs_stat(path=path)
_help_docs[stat] = "Get file metadata. Usage: stat(path)"

def exists(path):
    return fs_exists(path=path)
_help_docs[exists] = "Check if path exists. Usage: exists(path)"

def find(path=".", pattern="*"):
    return fs_find(path=path, pattern=pattern)
_help_docs[find] = "Find files by glob. Usage: find(path, pattern)"''';

  @override
  List<HostFunction> get functions => [
        _cat(),
        _ls(),
        _write(),
        _mkdir(),
        _rm(),
        _stat(),
        _exists(),
        _find(),
      ];

  /// Resolves [path] within the sandbox root and validates containment.
  ///
  /// When the target exists on disk, symlinks are resolved first so a
  /// malicious symlink inside the sandbox cannot escape the root.  When the
  /// target does not exist yet (e.g. a new file about to be written), the
  /// path is canonicalized (`.` / `..` collapsed) without requiring a real
  /// filesystem entity.
  ///
  /// Throws [ArgumentError] if the resolved path escapes the root.
  String _resolve(String path) {
    if (path.isEmpty) {
      throw ArgumentError('path must be a non-empty string.');
    }
    final joined = p.join(_rootPath, path);
    // Resolve symlinks when the entity exists; fall back to lexical
    // canonicalization for paths that don't exist yet (e.g. write targets).
    final normalized =
        FileSystemEntity.typeSync(joined) != FileSystemEntityType.notFound
            ? File(joined).resolveSymbolicLinksSync()
            : p.canonicalize(joined);
    if (!p.isWithin(_rootPath, normalized) && normalized != _rootPath) {
      throw ArgumentError('Path escapes sandbox root: $path');
    }
    return normalized;
  }

  // -- cat (read file) -----------------------------------------------------

  HostFunction _cat() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_cat',
          description: 'Read a UTF-8 text file and return its contents.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path within the sandbox root.',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          final resolved = _resolve(path);
          final file = File(resolved);
          if (!file.existsSync()) {
            throw ArgumentError('File does not exist: $path');
          }
          return file.readAsStringSync();
        },
      );

  // -- ls (list directory) -------------------------------------------------

  HostFunction _ls() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_ls',
          description: 'List directory entries with name and type. '
              'Optionally recurse into subdirectories.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path to a directory within the sandbox.',
            ),
            HostParam(
              name: 'recursive',
              type: HostParamType.boolean,
              description: 'Whether to list entries recursively.',
              isRequired: false,
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          final resolved = _resolve(path);
          final dir = Directory(resolved);
          if (!dir.existsSync()) {
            throw ArgumentError('Directory does not exist: $path');
          }
          final recursive = args['recursive'] == true;
          return dir
              .listSync(recursive: recursive)
              .map(
                (e) => <String, Object?>{
                  'name': p.relative(e.path, from: resolved),
                  'type': e is Directory ? 'directory' : 'file',
                },
              )
              .toList(growable: false);
        },
      );

  // -- write (write file) --------------------------------------------------

  HostFunction _write() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_write',
          description: 'Write UTF-8 text content to a file.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path within the sandbox root.',
            ),
            HostParam(
              name: 'content',
              type: HostParamType.string,
              description: 'Text content to write.',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          final content = args['content'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          if (content is! String) {
            throw ArgumentError('content must be a string.');
          }
          final resolved = _resolve(path);
          File(resolved).writeAsStringSync(content);
          return null;
        },
      );

  // -- mkdir ---------------------------------------------------------------

  HostFunction _mkdir() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_mkdir',
          description: 'Create a directory (and any missing parents) '
              'within the sandbox.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path within the sandbox root.',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          final resolved = _resolve(path);
          Directory(resolved).createSync(recursive: true);
          return null;
        },
      );

  // -- rm (delete file) ----------------------------------------------------

  HostFunction _rm() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_rm',
          description: 'Delete a file or empty directory.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path within the sandbox root.',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          final resolved = _resolve(path);
          final type = FileSystemEntity.typeSync(resolved);
          if (type == FileSystemEntityType.notFound) {
            throw ArgumentError('Path does not exist: $path');
          }
          if (type == FileSystemEntityType.directory) {
            Directory(resolved).deleteSync();
          } else {
            File(resolved).deleteSync();
          }
          return null;
        },
      );

  // -- stat ----------------------------------------------------------------

  HostFunction _stat() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_stat',
          description: 'Get file metadata: size, modified timestamp, '
              'and whether it is a directory.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path within the sandbox root.',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          final resolved = _resolve(path);
          final stat = FileStat.statSync(resolved);
          if (stat.type == FileSystemEntityType.notFound) {
            throw ArgumentError('Path does not exist: $path');
          }
          return <String, Object?>{
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
            'is_directory': stat.type == FileSystemEntityType.directory,
          };
        },
      );

  // -- exists (test -e) ----------------------------------------------------

  HostFunction _exists() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_exists',
          description: 'Check whether a file or directory exists.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path within the sandbox root.',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          // Use joined path (not resolved) to avoid error on non-existent.
          final joined = p.join(_rootPath, path);
          final normalized = p.normalize(joined);
          if (!p.isWithin(_rootPath, normalized) && normalized != _rootPath) {
            throw ArgumentError('Path escapes sandbox root: $path');
          }
          return FileSystemEntity.typeSync(normalized) !=
              FileSystemEntityType.notFound;
        },
      );

  // -- find (glob search) --------------------------------------------------

  HostFunction _find() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'fs_find',
          description: 'Recursively find files matching a glob pattern.',
          params: [
            HostParam(
              name: 'path',
              type: HostParamType.string,
              description: 'Relative path to a directory within the sandbox.',
            ),
            HostParam(
              name: 'pattern',
              type: HostParamType.string,
              description: 'Glob pattern to match (e.g. "*.txt", "**/*.dart").',
            ),
          ],
        ),
        handler: (args) async {
          final path = args['path'];
          final pattern = args['pattern'];
          if (path is! String) {
            throw ArgumentError('path must be a string.');
          }
          if (pattern is! String) {
            throw ArgumentError('pattern must be a string.');
          }
          final resolved = _resolve(path);
          final dir = Directory(resolved);
          if (!dir.existsSync()) {
            throw ArgumentError('Directory does not exist: $path');
          }
          final re = _globToRegExp(pattern);
          return dir
              .listSync(recursive: true)
              .where((e) => re.hasMatch(p.relative(e.path, from: resolved)))
              .map((e) => p.relative(e.path, from: resolved))
              .toList(growable: false);
        },
      );

  /// Converts a simple glob pattern to a [RegExp].
  ///
  /// Supports `*` (any non-separator chars) and `**` (any path segment).
  static RegExp _globToRegExp(String glob) {
    final buf = StringBuffer('^');
    var i = 0;
    while (i < glob.length) {
      final ch = glob[i];
      if (ch == '*') {
        if (i + 1 < glob.length && glob[i + 1] == '*') {
          // ** matches any number of path segments.
          buf.write('.*');
          i += 2;
          // Skip a trailing separator after **.
          if (i < glob.length && glob[i] == '/') i++;
          continue;
        }
        // * matches anything except path separator.
        buf.write('[^/]*');
      } else if (ch == '?') {
        buf.write('[^/]');
      } else if (ch == '.') {
        buf.write(r'\.');
      } else {
        buf.write(ch);
      }
      i++;
    }
    buf.write(r'$');
    return RegExp(buf.toString());
  }
}
