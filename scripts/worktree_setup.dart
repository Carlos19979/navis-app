// Prepares a fresh git worktree so it builds and passes the local checks.
// Run by Orca's setup hook (orca.yaml) from the new worktree's root:
//
//   dart scripts/worktree_setup.dart
//
// A worktree only carries what git tracks. The generated l10n files are
// committed and no model uses codegen, so what a fresh checkout lacks is the
// gitignored apps/api/.env and the Flutter package resolution.
// Written in Dart, not shell, because Orca runs the hook with cmd.exe on
// Windows and bash on macOS; Dart is on PATH on both via the Flutter SDK.
import 'dart:io';

Future<void> main() async {
  _copyApiEnv();
  await _run('flutter', ['pub', 'get'], 'apps/mobile');
  stdout.writeln('worktree setup: done');
}

/// Copies apps/api/.env from the main checkout (the first entry of
/// `git worktree list`), falling back to .env.example when it has none.
void _copyApiEnv() {
  final target = File('apps/api/.env');
  if (target.existsSync()) {
    stdout.writeln('worktree setup: apps/api/.env already present');
    return;
  }

  final list = Process.runSync('git', ['worktree', 'list', '--porcelain']);
  final mainPath = (list.stdout as String)
      .split('\n')
      .firstWhere((l) => l.startsWith('worktree '), orElse: () => '')
      .replaceFirst('worktree ', '')
      .trim();

  final fromMain = File('$mainPath/apps/api/.env');
  final source = mainPath.isNotEmpty && fromMain.existsSync()
      ? fromMain
      : File('apps/api/.env.example');
  source.copySync(target.path);
  stdout.writeln('worktree setup: apps/api/.env copied from ${source.path}');
}

Future<void> _run(String exe, List<String> args, String dir) async {
  stdout.writeln('worktree setup: $exe ${args.join(' ')}');
  final process = await Process.start(
    exe,
    args,
    workingDirectory: dir,
    mode: ProcessStartMode.inheritStdio,
    // flutter/dart are .bat wrappers on Windows and need a shell to resolve.
    runInShell: Platform.isWindows,
  );
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('worktree setup: $exe ${args.join(' ')} failed ($code)');
    exit(code);
  }
}
