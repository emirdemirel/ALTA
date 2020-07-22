#!/bin/bash

set -e -o pipefail

lang_suffix=
stage=
nj=39
train_set=train30_cleaned      
test_sets="dev test"
gmm=tri3b             # This specifies a GMM-dir from the features of the type you're training the system on;
                              # it should contain alignments for 'train_set'.
echo "$train_set"


nnet3_affix=_cleaned    # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                              # in the tedlium recip it's _cleaned).
gmm_dir=
ali_dir=
lat_dir=


echo "$0 $@" # Print the command line for logging

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh


if [ -f data/${train_set}_sp/feats.scp ] && [ $stage -le 7 ]; then
  echo "$0: $feats already exists.  Refusing to overwrite the features "
  echo " to avoid wasting time.  Please remove the file and continue if you really mean this."
  exit 1;
fi


if [ $stage -le 9 ]; then
  echo "$0: making MFCC features for low-resolution speed-perturbed data (needed for alignments)"
  steps/make_mfcc.sh --nj $nj \
    --cmd "$train_cmd" data/${train_set}_sp
  steps/compute_cmvn_stats.sh data/${train_set}_sp
  echo "$0: fixing input data-dir to remove nonexistent features, in case some "
  echo ".. speed-perturbed segments were too short."
  utils/fix_data_dir.sh data/${train_set}_sp
fi


if [ $stage -le 10 ]; then
  if [ -f $ali_dir/ali.1.gz ]; then
    echo "$0: alignments in $ali_dir appear to already exist.  Please either remove them "
    echo " ... or use a later --stage option."
    exit 1
  fi
  echo "$0: aligning with the perturbed low-resolution data"
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/${train_set}_sp data/lang$lang_suffix $gmm_dir $ali_dir
fi


if [ $stage -le 11 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/align_fmllr_lats.sh --nj 100 --cmd "$train_cmd" data/${train_set}_sp \
    data/lang${lang_suffix} $gmm_dir $lat_dir
  rm $lat_dir/fsts.*.gz # save space
fi


exit 0;
