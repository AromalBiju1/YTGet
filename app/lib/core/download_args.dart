List<String> buildMp3Args(String url, int kbps, String outTpl) => [
  '--extract-audio',
  '--audio-format',
  'mp3',
  '--audio-quality',
  '${kbps}K',
  '--no-playlist',
  '--newline',
  '--progress',
  '-o',
  outTpl,
  url,
];

List<String> buildMp4Args(String url, int maxH, String outTpl) => [
  '-f',
  'bv*[height<=$maxH]+ba/b/best',
  '--merge-output-format',
  'mp4',
  '--no-playlist',
  '--newline',
  '--progress',
  '-o',
  outTpl,
  url,
];

List<String> buildInfoArgs(String url) => [
  '--dump-json',
  '--no-playlist',
  '--skip-download',
  url,
];
