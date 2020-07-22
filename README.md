# ALTA - (A)utomatic (L)yrics (T)ranscription & (A)lignment

A kaldi recipe for automatic lyrics transcription and audio-to-lyrics alignment tasks.

If you use this repository, please cite it as follows:

```
@inproceedings{demirel2020,
  title={Automatic lyrics transcription using dilated convolutional neural networks with self-attention},
  author={Demirel, Emir and Ahlback, Sven and Dixon, Simon},
  booktitle={International Joint Conference on Neural Networks},
  year={2020}
}
```

## Setup

### 1) Kaldi  installation
This framework is built as a [Kaldi](http://kaldi-asr.org/)[1] recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi

### 2) Retrieve Data

The s5 recipe is based on the DSing!300x30x2 dataset within Smule's DAMP[2] repository. To retrieve the DSing!300x30x2, you need to apply for authorization from https://ccrma.stanford.edu/damp/.

## How to run

* Modify ```KALDI_ROOT``` in  ```s5/path.sh``` according to where your Kaldi installation is.

* Set the path to DAMP - Sing!300x30x2 data:

```
cd s5
damp_data='path-to-your-damp-directory'
```
We have provided the data files (at ```data/{train30_cleaned,dev,test}```) required in Kaldi pipelines for the ease of using this repository. 

* Execute the pipeline:
```
./run_damp.sh $damp_data
```

* If you have any problems during the pipeline, look up for the relevant process in ```run.sh```

**NOTE**: If you use ```dev``` and ```test``` sets in your experiments, please cite [3]


### References
[1] Povey, Daniel, et al. "The Kaldi speech recognition toolkit." IEEE 2011 workshop on automatic speech recognition and understanding. No. CONF. IEEE Signal Processing Society, 2011.

[2] Digital Archive of Mobile Performances (DAMP) portal hosted by the Stanford Center for Computer Research in Music and Acoustics (CCRMA) (https://ccrma.stanford.edu/damp/)

[3] Dabike, Gerardo Roa, and Jon Barker. "Automatic Lyric Transcription from Karaoke Vocal Tracks: Resources and a Baseline System." INTERSPEECH. 2019.
