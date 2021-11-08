#!/bin/bash

# Begin configuration section
nj=40
stage=1
decode_nj=1
output_path=out


. ./path.sh
. ./cmd.sh

set -e # exit on error

[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils


audio_path=$1 
output_path=$2 

rec_name=$(basename -- $audio_path)
audio_format=(${audio_path##*.})
rec_id=(${rec_name//$(echo ".$audio_format")/ })
echo $rec_id

. ./utils/parse_options.sh


echo; echo "===> START TIME : $(date +"%D_%T") ====="; echo


if [[ $stage -le 1 ]]; then

    echo "DATA PREPARATION"
    # Format the raw input lyrics and audio to be 
    # processed in the standard Kaldi format.
    # We prepare separate data directories
    # for the original and the source separated
    # recording.
    mkdir -p data/${rec_id}
    python3 local/data_preparation_ALT.py $audio_path data/${rec_id} 
    ./utils/fix_data_dir.sh data/${rec_id}
     
fi


mfccdir=mfcc
ivector_model=models/ivector/extractor
if [[ $stage -le 2 ]]; then
  echo "============================="
  echo "---- MFCC FEATURE EXTRACTION  ----"
  echo "=====  $(date +"%D_%T") ====="

  steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
    data/$rec_id exp/make_mfcc/$rec_id $mfccdir
  steps/compute_cmvn_stats.sh data/${rec_id}
  utils/fix_data_dir.sh data/${rec_id}

  echo "I-VECTOR EXTRACTION on VAD data"

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      data/${rec_id} $ivector_model exp/ivector/ivectors_${rec_id}

fi


tree_dir=models/tree
acoustic_model_dir=models/ctdnnsa_ivec
lang_dir=models/lang   # This is actually not a language model, rather pronunciation model,
                       # but the folder contains files that define that phoneme space.
if [[ $stage -le 3 ]]; then

  steps/chain/get_phone_post.sh --remove-word-position-dependency true \
    --online-ivector-dir exp/ivector/ivectors_${rec_id} \
    $tree_dir $acoustic_model_dir $lang_dir data/${rec_id} exp/phn_post_${rec_id}
  mkdir -p $output_path/${rec_id}
  python3 local/reformat_phone_post.py exp/phn_post_${rec_id} $output_path/${rec_id}

fi


echo
echo "=====  $(date +"%D_%T") ====="
echo "===== PROCESS ENDED ====="
echo

exit 1
