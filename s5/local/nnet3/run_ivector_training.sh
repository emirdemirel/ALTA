#!/bin/bash

set -e -o pipefail


lang_suffix=_2
stage=0
nj=39
train_set=train30_cleaned      
test_sets="dev test"


num_threads_ubm=32
nnet3_affix=_cleaned    # affix for exp/nnet3 directory to put iVector stuff

echo "$0 $@" 

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh



if [ $stage -le 0 ]; then
  # Extract iVectors for the training data.
  ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires
  temp_data_root=${ivectordir}
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/${train_set}_sp_hires ${temp_data_root}/${train_set}_sp_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    ${temp_data_root}/${train_set}_sp_hires_max2 \
    exp/nnet3${nnet3_affix}/extractor $ivectordir

fi


if [ $stage -le 1 ]; then
  # Also extract iVectors for the test data.
  for data in ${test_sets}; do
    nspk=$(wc -l <data/${data}_hires/spk2utt)
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
      data/${data}_hires exp/nnet3${nnet3_affix}/extractor \
      exp/nnet3${nnet3_affix}/ivectors_${data}_hires
  done
fi

exit 0;
