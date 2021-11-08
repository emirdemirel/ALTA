# ALTA :
## Automatic lyrics transcription using dilated convolutional neural networks with self-attention

A kaldi recipe for monophonic automatic lyrics transcription task using single-stream acoustic models and RNNLM rescoring. The neural network architecture has a self-attention layer on top, which is found to reduce complexity of the final decoding search space.

For more information, please refer to the paper below:
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

## How to run

* Modify ```KALDI_ROOT``` in  ```s5/path.sh``` according to where your Kaldi installation is.

### A) Running the lyrics transcription - training pipeline

* Retrieve Data:

The s5 recipe is based on the DSing!300x30x2 dataset within Smule's DAMP[2] repository. To retrieve the DSing!300x30x2, you need to apply for authorization from https://ccrma.stanford.edu/damp/.

* Set the path to DAMP - Sing!300x30x2 data:

```
cd s5
damp_data='path-to-your-damp-directory'
```
We have provided the data files (at ```data/{train,dev,test}_damp```) required in Kaldi pipelines for the ease of using this repository. 

* Execute the pipeline:
```
./run_damp.sh $damp_data
```

* If you have any problems during the pipeline, look up for the relevant process in ```run.sh```


## System Details

Automatic Lyrics Transcription is the task of translating singing voice into text. Jusy like in hybrid speech recognition, our lyrics transcriber consists of separate acoustic, language and pronunciation models.

<p align="center">
  <img src="https://github.com/emirdemirel/ALTA/blob/master/img/img-git1.png" width="550" height="160">
</p>

**Acoustic Model**: Sequence discriminative training on MMI criteria[3].

The neural network architecture consists of 2D Convolutions, factorized time-delay and self-attention layers:
<p align="center">
    <img src="https://github.com/emirdemirel/ALTA/blob/master/img/img-git2.png?raw=true" width="250" height="310">
</p>

**Language Model**: We use the lyrics of recent (2015-2018) popular songs for training the LM (```s5/conf/corpus.txt```).

**Pronunciation Model**: The standard CMU-Sphinx English pronunciation dictionary (http://www.speech.cs.cmu.edu/cgi-bin/cmudict). 


### References
[1] Povey, Daniel, et al. "The Kaldi speech recognition toolkit." IEEE 2011 workshop on automatic speech recognition and understanding. No. CONF. IEEE Signal Processing Society, 2011.

[2] Digital Archive of Mobile Performances (DAMP) portal hosted by the Stanford Center for Computer Research in Music and Acoustics (CCRMA) (https://ccrma.stanford.edu/damp/)

[3] Povey, Daniel, et al. "Purely sequence-trained neural networks for ASR based on lattice-free MMI." Interspeech. 2016.

### Important Notice:
This work is licensed under Creative Commons - Attribution-NonCommercial-ShareAlike 4.0 International, which means that the reusers can copy, distribute, remix, transform and build upon the material in any media providing the appropriate credits to this repository and to be used for non-commercial purposes.
