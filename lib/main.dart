import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const KrushyyApp());

const purple = Color(0xFF9B7BFF);
const background = Color(0xFF090A10);
const panel = Color(0xFF171A25);

class KrushyyApp extends StatelessWidget {
  const KrushyyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KRUSHYY ENHANCER',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: purple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const EnhancerPage(),
      );
}

class EnhancerPage extends StatefulWidget {
  const EnhancerPage({super.key});

  @override
  State<EnhancerPage> createState() => _EnhancerPageState();
}

class _EnhancerPageState extends State<EnhancerPage> {
  String? inputPath;
  String? outputPath;
  bool busy = false;
  bool sharpen = true;
  bool denoise = false;
  bool interpolate = false;
  int fps = 60;
  int height = 1080;
  double crf = 20;
  String status = 'Choose a video to begin.';
  String? errorText;

  String quote(String value) =>
      '"${value.replaceAll(r'\\', r'\\\\').replaceAll('"', r'\\"')}"';

  Future<void> pickVideo() async {
    if (busy) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) {
        setState(() => errorText = 'Could not read this file. Try a video stored on your device.');
        return;
      }
      setState(() {
        inputPath = path;
        outputPath = null;
        errorText = null;
        status = 'Video ready';
      });
    } catch (e) {
      setState(() => errorText = 'Video picker failed: $e');
    }
  }

  Future<void> enhance() async {
    final source = inputPath;
    if (source == null || busy) return;
    if (!await File(source).exists()) {
      setState(() => errorText = 'The selected video was not found. Please select it again.');
      return;
    }
    setState(() {
      busy = true;
      errorText = null;
      outputPath = null;
      status = 'Preparing video…';
    });

    try {
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory('${docs.path}/KrushyyExports');
      await folder.create(recursive: true);
      final destination = '${folder.path}/krushyy_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final filters = <String>['scale=-2:$height:flags=lanczos'];
      if (denoise) filters.add('hqdn3d=1.5:1.5:6:6');
      if (sharpen) filters.add('unsharp=5:5:0.8:3:3:0.4');
      if (interpolate && fps > 60) {
        filters.add('minterpolate=fps=$fps:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1');
      }

      final args = <String>[
        '-hide_banner', '-y',
        '-i', quote(source),
        '-vf', quote(filters.join(',')),
        if (interpolate && fps > 60) ...['-r', '$fps'],
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', crf.round().toString(),
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-movflags', '+faststart',
        quote(destination),
      ];
      final done = Completer<void>();
      setState(() => status = interpolate && fps > 60
          ? 'Creating intermediate frames…'
          : 'Enhancing and compressing…');

      await FFmpegKit.executeAsync(
        args.join(' '),
        (session) async {
          final code = await session.getReturnCode();
          if (!mounted) {
            if (!done.isCompleted) done.complete();
            return;
          }
          if (ReturnCode.isSuccess(code) && await File(destination).exists()) {
            setState(() {
              outputPath = destination;
              status = 'Enhancement complete!';
              busy = false;
            });
          } else {
            final log = await session.getOutput();
            setState(() {
              errorText = 'FFmpeg could not process this clip. ${(log ?? '').split('\n').take(4).join(' ')}';
              status = 'Processing failed';
              busy = false;
            });
          }
          if (!done.isCompleted) done.complete();
        },
        (log) {},
        (statistics) {},
      );
      await done.future;
    } catch (e) {
      if (mounted) {
        setState(() {
          errorText = 'Could not process video: $e';
          status = 'Processing failed';
          busy = false;
        });
      }
    }
  }

  Future<void> shareResult() async {
    final path = outputPath;
    if (path == null || !await File(path).exists()) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'KRUSHYY ENHANCER video',
      ),
    );
  }

  Future<void> cancel() async {
    await FFmpegKit.cancel();
    if (mounted) {
      setState(() {
        busy = false;
        status = 'Cancelled';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = inputPath?.split(Platform.pathSeparator).last ?? 'No video selected';
    return Scaffold(
      appBar: AppBar(
        title: const Text('KRUSHYY ENHANCER',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: Text('BETA', style: TextStyle(color: purple, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF302650), Color(0xFF171A28)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MAKE EVERY FRAME\nLOOK BETTER.',
                        style: TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w900)),
                    SizedBox(height: 8),
                    Text('Import. Enhance. Export.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _heading('01', 'YOUR VIDEO'),
              const SizedBox(height: 9),
              Card(
                color: panel,
                child: ListTile(
                  onTap: busy ? null : pickVideo,
                  leading: const Icon(Icons.video_library, color: purple, size: 30),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(inputPath == null ? 'Tap to choose a video' : 'Tap to change video'),
                  trailing: const Icon(Icons.add_circle_outline, color: purple),
                ),
              ),
              const SizedBox(height: 18),
              _heading('02', 'OUTPUT SETTINGS'),
              const SizedBox(height: 9),
              _dropdown<int>(
                'Resolution',
                height,
                const [720, 1080, 1440, 2160],
                (v) => setState(() => height = v),
                (v) => v == 2160 ? '4K' : v == 1440 ? '1440p' : '${v}p',
              ),
              const SizedBox(height: 9),
              _dropdown<int>(
                'Frame rate',
                fps,
                const [30, 60, 120, 144, 240],
                (v) => setState(() => fps = v),
                (v) => '$v FPS',
              ),
              const SizedBox(height: 9),
              Card(
                color: panel,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Compression quality  •  CRF ${crf.round()}'),
                    Slider(
                      value: crf,
                      min: 16,
                      max: 30,
                      divisions: 14,
                      onChanged: busy ? null : (v) => setState(() => crf = v),
                    ),
                    const Text('Lower CRF keeps more detail but creates a larger file.',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              _heading('03', 'ENHANCEMENTS'),
              _switch('Sharpen details', 'Makes edges look crisper.', sharpen,
                  (v) => setState(() => sharpen = v), Icons.auto_fix_high),
              _switch('Reduce noise', 'Reduces grain in the image.', denoise,
                  (v) => setState(() => denoise = v), Icons.blur_off),
              _switch('Frame interpolation', 'Generates in-between frames for 120/144/240 FPS. Very demanding.',
                  interpolate, (v) => setState(() => interpolate = v), Icons.slow_motion_video),
              const SizedBox(height: 14),
              Card(
                color: const Color(0xFF12211F),
                child: ListTile(
                  leading: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(outputPath != null ? Icons.check_circle : Icons.info_outline,
                          color: outputPath != null ? Colors.greenAccent : purple),
                  title: Text(status),
                  subtitle: errorText == null
                      ? Text(busy ? 'Processing can take several minutes.' : 'Your original video will not be changed.')
                      : Text(errorText!, style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
              const SizedBox(height: 12),
              if (busy)
                OutlinedButton.icon(
                  onPressed: cancel,
                  icon: const Icon(Icons.stop),
                  label: const Text('CANCEL'),
                )
              else
                FilledButton.icon(
                  onPressed: inputPath == null ? pickVideo : enhance,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(inputPath == null ? 'CHOOSE VIDEO' : 'ENHANCE VIDEO'),
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              if (outputPath != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: shareResult,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('SAVE / SHARE RESULT'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
              const SizedBox(height: 20),
              const Text('KRUSHYY • MADE FOR EDITORS',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String n, String title) => Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: purple.withValues(alpha: .18),
          child: Text(n, style: const TextStyle(color: purple, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 9),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ]);

  Widget _dropdown<T>(
    String title,
    T value,
    List<T> values,
    ValueChanged<T> onChanged,
    String Function(T) label,
  ) =>
      Card(
        color: panel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          child: DropdownButtonFormField<T>(
            value: value,
            decoration: InputDecoration(labelText: title, border: InputBorder.none),
            dropdownColor: panel,
            items: values.map((v) => DropdownMenuItem(value: v, child: Text(label(v)))).toList(),
            onChanged: busy ? null : (v) { if (v != null) onChanged(v); },
          ),
        ),
      );

  Widget _switch(String title, String subtitle, bool value,
          ValueChanged<bool> changed, IconData icon) =>
      Card(
        color: panel,
        child: SwitchListTile(
          secondary: Icon(icon, color: purple),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          value: value,
          onChanged: busy ? null : changed,
          activeThumbColor: purple,
        ),
      );
}
