#!/bin/bash

set -e -o pipefail

# This script is called from scripts like local/nnet3/run_tdnn.sh and
# local/chain/run_tdnn.sh (and may eventually be called by more scripts).  It
# contains the common feature preparation and iVector-related parts of the
# script.  See those scripts for examples of usage.

stage=1
nj=39
train_set=train    # you might set this to e.g. train.


num_threads_ubm=32
nnet3_affix=_cleaned    # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                              # in the tedlium recip it's _cleaned).
echo "$0 $@" # Print the command line for logging

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh


if [ $stage -le 1 ]; then
  echo "$0: computing a subset of data to train the diagonal UBM."

  mkdir -p exp/nnet3${nnet3_affix}/diag_ubm
  temp_data_root=exp/nnet3${nnet3_affix}/diag_ubm

  # train a diagonal UBM using a subset of about a quarter of the data
  num_utts_total=$(wc -l <data/${train_set}_sp_hires/utt2spk)
  num_utts=$[$num_utts_total/4]
  utils/data/subset_data_dir.sh data/${train_set}_sp_hires \
      $num_utts ${temp_data_root}/${train_set}_sp_hires_subset

  echo "$0: computing a PCA transform from the hires data."
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
      --splice-opts "--left-context=3 --right-context=3" \
      --max-utts 10000 --subsample 2 \
       ${temp_data_root}/${train_set}_sp_hires_subset \
       exp/nnet3${nnet3_affix}/pca_transform

  echo "$0: training the diagonal UBM."
  # Use 512 Gaussians in the UBM.
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 30 \
    --num-frames 700000 \
    --num-threads $num_threads_ubm \
    ${temp_data_root}/${train_set}_sp_hires_subset 512 \
    exp/nnet3${nnet3_affix}/pca_transform exp/nnet3${nnet3_affix}/diag_ubm

fi

if [ $stage -le 4 ]; then
  # Train the iVector extractor.  Use all of the speed-perturbed data since iVector extractors
  # can be sensitive to the amount of data.  The script defaults to an iVector dimension of
  # 100.
  echo "$0: training the iVector extractor"
  # in steps/online/nnet2/train_ivector_extractor.sh calculate nj_full as
  # num_threads * num_processes
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 10 \
    --num_threads 1 --num_processes 1 \
    data/${train_set}_sp_hires exp/nnet3${nnet3_affix}/diag_ubm exp/nnet3${nnet3_affix}/extractor || exit 1;
fi


exit 0;
