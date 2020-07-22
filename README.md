# ALTA - (A)utomatic (L)yrics (T)ranscription & (A)lignment

A kaldi recipe for automatic lyrics transcription and audio-to-lyrics alignment tasks.


## Setup

### 1) Kaldi  installation
This framework is built as a [Kaldi](http://kaldi-asr.org/) recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi

### 2) Retrieve Data

The s5 recipe is based on the DSing!300x30x2 dataset within Smule's [DAMP](https://ccrma.stanford.edu/damp/) repository. To retrieve the DSing!300x30x2, you need to apply for authorization from https://ccrma.stanford.edu/damp/.

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
./run.sh $damp_data
```

* If you have any problems during the pipeline, look up for the relevant process in ```run.sh```

**NOTE**: If you use ```dev``` and ```test``` sets in your experiments, please cite [^f1]


### References

[^f1] Dabike, Gerardo Roa, and Jon Barker. "Automatic Lyric Transcription from Karaoke Vocal Tracks: Resources and a Baseline System." INTERSPEECH. 2019.
