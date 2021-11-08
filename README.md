# ALTA - (A)utomatic (L)yrics (T)r(A)nscription

A kaldi recipe for automatic lyrics transcription task.





## System Details

Automatic Lyrics Transcription is the task of translating singing voice into text. Jusy like in hybrid speech recognition, our lyrics transcriber consists of separate acoustic, language and pronunciation models.

<p align="center">
  <img src="https://github.com/emirdemirel/ALTA/blob/master/img/img-git1.png" width="550" height="160">
</p>

**Acoustic Model**: Sequence discriminative training on LF-MMI criteria[3] (Kaldi-chain recipe).

**Language Model**: The LM is a 4-gram MaxEnt trained using the SRILM toolkit, where Kneser-Ney smoothing applied.  

**Pronunciation Model**: A predefined lexicon that provides a mapping between words and their phonemic representations.




## Setup

### A) Docker Installation

The easiest way to install this package is through Docker. For this you will need to have Docker engine installed in your machine. You can find the installation instructions for this [here](https://docs.docker.com/engine/install/).

### 1) Build the Docker image
To install the ALTA package in a Docker container, simply navigate to where this repository is located and run:
```
docker build --tag alta:latest -f Dockerfile . 
```
### 2) Run the Docker container



### B) Local Installation

#### 1) Kaldi

This framework is built as a [Kaldi](http://kaldi-asr.org/)[1] recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi

#### 2) Dependencies

```
pip install -r requirements.txt
```


## How to run

* Modify ```KALDI_ROOT``` in  ```s5/path.sh``` according to where your Kaldi installation is.

### A) Retrieve the data:

* DAMP:

We use the Sing!300x30x2 data within the DAMP repository. To retrieve the data, you need to apply for authorization from https://ccrma.stanford.edu/damp/ .
The train/dev/test splits are automatically done within this recipe.

* DALI:

DALI_v2.0 is used to train the polyphonic and cross-domain lyrics transcription models. To retrieve the data, please refer to the relevant Github repository at:

https://github.com/gabolsgabs/DALI

* DALI-TALT:

This dataset is a subset of DALI, presented in .... It is the largest test set used for evaluating polyphonic ALT models. The data can be retrieved via the tutorial at: https://github.com/emirdemirel/DALI-TestSet4ALT .

* Jamendo:

Jamendo(lyrics) is a benchmark evaluation set for both lyrics transcription and audio-to-lyrics alignment tasks. It is also used in MIREX challenges. Data can be retrieved at https://github.com/f90/jamendolyrics .

### B) Running the training pipeline

There are two recipes included in this repository. The first one is a single-stream CTDNN - self-attention based acoustic model with RNNLM rescoring (1) presented in .., and the MStre-Net recipe which has a multistream cross-domain acoustic model(2), which is published in ISMIR2021.

For (1), please navigate to ```Model_SingleStream/ ```, and for (2), ```MStre-Net```. The recipe-specific Readme's are provided within these directories.



### C) (OPTIONAL) Extract frame-level Phoneme posteriorgrams:

Run the script for extracting the phoneme posteriorgrams as follows:

```
audio_path='absolute-path-to-the-input-audio-file'
save_path='path-to-save-the-output
cd s5
./extract_phn_posteriorgram.sh $audio_path $save_path
```

The output posteriorgrams are saved as numpy arrays (.npy).

Note that we have used 16kHz for the sample rate and 10ms of hop size.

### Future Work

* End-to-end recipe based SpeechBrain toolkit.

### Citation

If you use the MStreNet recipe, which is the state-of-the-art model for automatic lyrics transcription, please cite following paper:
```
  @article{demirel2021mstre,
  title={MSTRE-Net: Multistreaming Acoustic Modeling for Automatic Lyrics Transcription},
  author={Demirel, Emir and Ahlb{\"a}ck, Sven and Dixon, Simon},
  booktitle={In proceedings of ISMIR2021},
  year={2021}
}
```
Link to paper : https://arxiv.org/pdf/2108.02625.pdf


If you use the recipe for the single-stream approach with RNNLM rescoring, please cite the paper below:
```
@inproceedings{demirel2020,
  title={Automatic lyrics transcription using dilated convolutional neural networks with self-attention},
  author={Demirel, Emir and Ahlback, Sven and Dixon, Simon},
  booktitle={International Joint Conference on Neural Networks},
  publisher={IEEE},
  year={2020}
}
```

Link to paper : https://arxiv.org/abs/2007.06486



### References
[1] Povey, Daniel, et al. "The Kaldi speech recognition toolkit." IEEE 2011 workshop on automatic speech recognition and understanding. No. CONF. IEEE Signal Processing Society, 2011.

[2] Digital Archive of Mobile Performances (DAMP) portal hosted by the Stanford Center for Computer Research in Music and Acoustics (CCRMA) (https://ccrma.stanford.edu/damp/)

[3] Dabike, Gerardo Roa, and Jon Barker. "Automatic Lyric Transcription from Karaoke Vocal Tracks: Resources and a Baseline System." INTERSPEECH. 2019.

[4] Povey, Daniel, et al. "Purely sequence-trained neural networks for ASR based on lattice-free MMI." Interspeech. 2016.

### Important Notice:
This work is licensed under Creative Commons - Attribution-NonCommercial-ShareAlike 4.0 International, which means that the reusers can copy, distribute, remix, transform and build upon the material in any media providing the appropriate credits to this repository and to be used for non-commercial purposes.
