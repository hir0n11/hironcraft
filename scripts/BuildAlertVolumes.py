"""Bake independent 10%-step volumes without touching WoW's global mixer.

Build dependency: imageio-ffmpeg. Original media and licences are kept.
Only generated binary audio is written, never source/configuration files.
"""
from pathlib import Path
import subprocess
from imageio_ffmpeg import get_ffmpeg_exe

media = Path(__file__).resolve().parent.parent / 'Media'
sources = [media / 'WhisperAlert.ogg', *sorted(p for p in (media / 'SharedMedia' / 'Sounds').iterdir()
                                           if p.suffix.lower() in ('.ogg', '.mp3'))]
for source in sources:
    print(source.name, flush=True)
    command=[get_ffmpeg_exe(), '-nostdin', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source)]
    for level in range(10, 100, 10):
        target = (media / 'AlertVolume' / str(level) / source.relative_to(media)).with_suffix('.ogg')
        target.parent.mkdir(parents=True, exist_ok=True)
        command.extend(['-map','0:a:0','-af',f'volume={level/100}', '-c:a','libvorbis','-q:a','4',str(target)])
    subprocess.run(command,check=True)
print(f'Generated {len(sources)*9} volume variants from {len(sources)} sounds.')
