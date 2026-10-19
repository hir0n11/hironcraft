"""Verify the shipped volume catalogue and decoded RMS, not just filenames."""
from pathlib import Path
import subprocess
import numpy as np
from imageio_ffmpeg import get_ffmpeg_exe

media=Path(__file__).resolve().parent.parent/'Media'
sources=[media/'WhisperAlert.ogg',*sorted(p for p in (media/'SharedMedia'/'Sounds').iterdir()
                                      if p.suffix.lower() in ('.ogg','.mp3'))]
expected=set()
for source in sources:
    for level in range(10,100,10):
        target=(media/'AlertVolume'/str(level)/source.relative_to(media)).with_suffix('.ogg')
        expected.add(target)
        assert target.is_file(), target
        with target.open('rb') as stream:
            assert stream.read(4)==b'OggS', target
assert set((media/'AlertVolume').rglob('*.ogg'))==expected
def rms(path):
    data=subprocess.run([get_ffmpeg_exe(),'-nostdin','-v','error','-i',str(path),'-f','f32le','-'],
                        check=True,stdout=subprocess.PIPE).stdout
    samples=np.frombuffer(data,dtype='<f4').astype(np.float64)
    assert len(samples)>0 and np.isfinite(samples).all(),path
    return np.sqrt(np.mean(samples*samples)),len(samples)
for name in ('WhisperAlert.ogg','SharedMedia/Sounds/AcousticGuitar.ogg','SharedMedia/Sounds/Brass.mp3'):
    original,count=rms(media/name)
    for level in (10,50,90):
        scaled,n=rms((media/'AlertVolume'/str(level)/name).with_suffix('.ogg'))
        assert abs(n-count)<4096,(name,n,count)
        assert abs(scaled/original-level/100)<0.035,(name,level,scaled/original)
print(f'Audio verification passed: {len(expected)} variant headers/paths, OGG/MP3 decoding and nine RMS/duration comparisons.')
