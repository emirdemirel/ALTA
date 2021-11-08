  - The data identifiers and sentence annotations for the NUS Corpus can be found in directories ```nus_sing``` and ```nus_sing_whole```.
  - ```nus_sing_whole``` is the unsegmented version of ```nus_sing```.
  - The NUS Corpus can be retrieved from https://smcnus.comp.nus.edu.sg/nus-48e-sung-and-spoken-lyrics-corpus/
  - The files have Kaldi format. 
  - 'text' has the lyrics annotations
  - 'segments' has the timing annotatations on the sentence / lyrics-line level.
  - 'utt2spk' has the singer ID information.
  - 'wav.scp' is for loading audio files. This file has path to audio. You need to change ```$AUDIO_PATH``` with where you locate the NUS Corpus.
  - The results in the paper "Computational Pronunciation Analysis in Sung Utterances" are reported on ```nus_sing```.

