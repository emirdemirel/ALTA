#!/bin/bash

set -e -o pipefail
export CUDA_VISIBLE_DEVICES=1,2
stage=12
nj=30
train_set=train_damp
#train_set=train_damp
test_sets="test nus_sing_whole"
gmm=tri4b      # this is the source gmm-dir that we'll use for alignments; it
                 # should have alignments for the specified training data.

nnet3_affix=_cleaned
chain_affix=_mstrenet
# Options which are not passed through to run_ivector_common.sh
common_egs_dir=

data_affix=$1
lang_suffix=
#train_stage=-10
train_stage=$2
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'

# training chunk-options
chunk_width=48,96,150



label_delay=5

# training options
srand=0
remove_egs=false

#decode options
test_online_decoding=false  # if true, it will run the last decoding stage.

# End configuration section.
echo "$0 $@"  # Print the command line for logging


. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi


gmm_dir=exp_v3/tri6b
ali_dir=exp_v3/tri6b_ali_${train_set}
lat_dir=exp_v3/chain_${train_set}/tri6b_${train_set}_lats

for f in data/${train_set}/feats.scp ; do
  if [ ! -f $f ]; then
    echo "$0: expected file $f to exist"
    exit 1
  fi
done





if [ $stage -le -1 ]; then
  echo " ====================== "
  echo " ---  Data Augmentation - 3-way Speed Perturbation  ---  "
  echo " ====================== "
  echo 
  echo "$0: preparing directory for speed-perturbed data"
  utils/data/perturb_data_dir_speed_3way.sh data/${train_set} data/${train_set}_sp
fi





if [ $stage -le 2 ]; then
  echo " ====================== "
  echo "$0: creating high-resolution MFCC features"
  echo " ====================== "
  echo

  for datadir in ${train_set}; do
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
  done

  # do volume-perturbation on the training data prior to extracting hires
  # features; this helps make trained nnets more invariant to test data volume.
  #utils/data/perturb_data_dir_volume.sh data/${train_set}_sp_hires

  for datadir in ${train_set}; do
    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" data/${datadir}_hires
    steps/compute_cmvn_stats.sh data/${datadir}_hires
    utils/fix_data_dir.sh data/${datadir}_hires
  done
  #stage=9
fi


if [ $stage -le 3 ]; then
  echo " ====================== "
  echo " ---  i-Vector Training - for singer adaptive NN training ---  "
  echo " ====================== "
  echo 
  local/nnet3/run_ivector_training.sh \
    --stage 0 --nj $nj --nnet3_affix _libri --affix _v3\
    --train_set $train_set 
fi



#Configuration
dir=exp$lang_suffix/chain_cleaned/mstrenet

train_data_dir=data/${train_set}_hires
train_ivector_dir=exp_v3/nnet3${nnet3_affix}/ivectors_${train_set}_hires
lores_train_data_dir=data/${train_set}

tree_dir=exp_v3/chain${chain_affix}/tree
lang=data/lang${lang_suffix}_chain



if [ $stage -le -5 ]; then
  echo " ====================== "
  echo "$0: creating low-resolution MFCC features on augmented data - needed for alignment"
  echo " ====================== "
  echo
  mfccdir=data/${train_set}_sp/data

  for datadir in ${train_set}_sp; do
    steps/make_mfcc.sh --nj $nj  \
      --cmd "$train_cmd" data/${datadir}
    steps/compute_cmvn_stats.sh data/${datadir}
    utils/fix_data_dir.sh data/${datadir}
  done
fi


if [ $stage -le 6 ]; then
  if [ -f $ali_dir/ali.1.gz ]; then
    echo "$0: alignments in $ali_dir appear to already exist.  Please either remove them "
    echo " ... or use a later --stage option."
    exit 1
  fi
  echo "$0: aligning with the perturbed low-resolution data"
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/${train_set} data/lang$lang_suffix $gmm_dir $ali_dir
fi


if [ $stage -le 7 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/align_fmllr_lats.sh --nj 40 --cmd "$train_cmd" \
    data/${train_set} data/lang${lang_suffix} $gmm_dir $lat_dir
  rm $lat_dir/fsts.*.gz # save space
  stage=10
fi



if [ $stage -le 8 ]; then
  echo "$0: create sing lang directory $lang with chain-type topology"
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
    cp -r data/lang_4G $lang

    silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
    # Use our special topology... note that later on may have to tune this
    # topology.
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo

fi

if [ $stage -le 9 ]; then
  echo " ====================== "
  echo " ====================== "
  echo

  mfccdir=data/${train_set}_hires/data

  for datadir in ${train_set}; do
    nspk=$(wc -l <data/${datadir}_hires/spk2utt)
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
      data/${datadir}_hires exp/nnet3${nnet3_affix}/extractor \
      exp/nnet3${nnet3_affix}/ivectors_${datadir}_hires
  done
fi


for f in $train_data_dir/feats.scp exp/nnet3${nnet3_affix}/ivectors_${train_set}_hires/ivector_online.scp \
    $lores_train_data_dir/feats.scp $gmm_dir/final.mdl \
    $ali_dir/ali.1.gz; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done


if [ $stage -le 10 ]; then
  # Build a tree using our new topology.  We know we have alignments for the
  # speed-perturbed data (local/nnet3/run_alignment_gmm_sp.sh made them), so use
  # those. 
   if [ -f $tree_dir/final.mdl ]; then
     echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
     exit 1;
  fi
  steps/nnet3/chain/build_tree.sh \
    --frame-subsampling-factor 3 \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$train_cmd" 6000 ${lores_train_data_dir} \
    $lang $ali_dir $tree_dir
fi



if [ $stage -le 11 ]; then
  mkdir -p $dir
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print (0.5/$xent_regularize)" | python)
  cnn_opts="l2-regularize=0.01"
  ivector_affine_opts="l2-regularize=0.01"
  tdnn_opts="l2-regularize=0.01 dropout-proportion=0.2 dropout-per-dim-continuous=true"
  tdnnf_first_opts="l2-regularize=0.01 dropout-proportion=0.2 bypass-scale=0.0"
  tdnnf_opts="l2-regularize=0.01 dropout-proportion=0.2 bypass-scale=0.66"
  relu_bn_opts="l2-regularize=0.01 dropout-proportion=0.2"
  linear_opts="l2-regularize=0.01 orthonormal-constraint=-1.0"
  prefinal_opts="l2-regularize=0.01"
  lstm_opts="decay-time=20 dropout-proportion=0.0"
  output_opts="l2-regularize=0.005"

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # this takes the MFCCs and generates filterbank coefficients.  The MFCCs
  # are more compressible so we prefer to dump the MFCCs to disk rather
  # than filterbanks.
  idct-layer name=idct input=input dim=40 cepstral-lifter=22 affine-transform-file=$dir/configs/idct.mat

  linear-component name=ivector-linear $ivector_affine_opts dim=200 input=ReplaceIndex(ivector, t, 0)
  batchnorm-component name=ivector-batchnorm target-rms=0.025

  batchnorm-component name=idct-batchnorm input=idct
  combine-feature-maps-layer name=combine_inputs input=Append(idct-batchnorm, ivector-batchnorm) num-filters1=1 num-filters2=5 height=40

  conv-relu-batchnorm-layer name=cnn1 $cnn_opts height-in=40 height-out=40 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=48 learning-rate-factor=0.333 max-change=0.25
  conv-relu-batchnorm-layer name=cnn2 $cnn_opts height-in=40 height-out=40 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=48
  conv-relu-batchnorm-layer name=cnn3 $cnn_opts height-in=40 height-out=20 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn4 $cnn_opts height-in=20 height-out=20 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn5 $cnn_opts height-in=20 height-out=10 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn6 $cnn_opts height-in=10 height-out=5 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=128
  # the first TDNN-F layer has no bypass (since dims don't match), and a larger bottleneck so the
  # information bottleneck doesn't become a problem.
  tdnnf-layer name=tdnnf1 $tdnnf_first_opts dim=512 bottleneck-dim=256 time-stride=0 input=cnn6
  tdnnf-layer name=tdnnf2 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf3 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf4 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf5 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf6 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf7 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf8 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf9 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3  
  tdnnf-layer name=tdnnf10 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=3    
  
  tdnnf-layer name=tdnnf1_2 $tdnnf_first_opts dim=512 bottleneck-dim=256 time-stride=0 input=cnn6
  tdnnf-layer name=tdnnf2_2 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=6
  tdnnf-layer name=tdnnf3_2 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=6
  tdnnf-layer name=tdnnf4_2 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=6
  tdnnf-layer name=tdnnf5_2 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=6

        
  tdnnf-layer name=tdnnf1_3 $tdnnf_first_opts dim=512 bottleneck-dim=256 time-stride=0 input=cnn6
  tdnnf-layer name=tdnnf2_3 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=9
  tdnnf-layer name=tdnnf3_3 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=9
  tdnnf-layer name=tdnnf4_3 $tdnnf_opts dim=512 bottleneck-dim=128 time-stride=9
  
  linear-component name=prefinal-l dim=256 input=Append(tdnnf10,tdnnf5_2,tdnnf4_3) $linear_opts

  prefinal-layer name=prefinal-chain input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts

  prefinal-layer name=prefinal-xent input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts

EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


if [ $stage -le 12 ]; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{4,5,6,7}/$USER/kaldi-data/egs/wsj-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi

  steps/nnet3/chain/train.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir=$train_ivector_dir \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient=0.1 \
    --chain.l2-regularize=0.0 \
    --chain.apply-deriv-weights=false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --trainer.dropout-schedule $dropout_schedule \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
    --trainer.num-epochs=6 \
    --trainer.frames-per-iter=3000000 \
    --trainer.optimization.num-jobs-initial=2 \
    --trainer.optimization.num-jobs-final=2 \
    --trainer.optimization.initial-effective-lrate=0.0005 \
    --trainer.optimization.final-effective-lrate=0.00005 \
    --trainer.num-chunk-per-minibatch=32,16 \
    --trainer.optimization.momentum=0.0 \
    --egs.chunk-width=$chunk_width \
    --egs.dir="$common_egs_dir" \
    --egs.opts="--frames-overlap-per-eg 0" \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=true \
    --reporting.email="$reporting_email" \
    --feat-dir=$train_data_dir \
    --tree-dir=$tree_dir \
    --lat-dir=$lat_dir \
    --dir=$dir  || exit 1;
fi



graph_dir=$dir/graph_4G$lang_suffix
if [ $stage -le 13 ]; then
  utils/mkgraph.sh --self-loop-scale 1.0 --remove-oov data/lang_4G${lang_suffix} $dir $graph_dir
  # remove <UNK> from the graph, and convert back to const-FST.
  fstrmsymbols --apply-to-output=true --remove-arcs=true "echo 3|" $graph_dir/HCLG.fst - | \
    fstconvert --fst_type=const > $graph_dir/temp.fst
  mv $graph_dir/temp.fst $graph_dir/HCLG.fst
fi



if [[ $stage -le 14 ]]; then

  echo
  echo "============================="
  echo "---- I-vectors ----"
  echo "=====  $(date +"%D_%T") ====="
  echo

  for datadir in test nus_sing_whole; do
    nspk=$(wc -l <data/${datadir}_hires/spk2utt)
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
      data/${datadir}_hires exp/nnet3${nnet3_affix}/extractor \
      exp/nnet3${nnet3_affix}/ivectors_${datadir}_hires

  done
fi


iter=100

if [ $stage -le 15 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  rm $dir/.error 2>/dev/null || true

  for data in test nus_sing_whole; do
    (
      data_affix=$(echo $data | sed s/test_//)
      nspk=$(wc -l <data/${data}_hires/spk2utt)
      for lmtype in 4G${lang_suffix}; do
        steps/nnet3/decode.sh \
          --acwt 1.0 --post-decode-acwt 10.0 \
          --frames-per-chunk $frames_per_chunk \
          --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
          --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_${data}_hires \
          $graph_dir data/${data}_hires ${dir}/decode_${lmtype}_${data_affix} || exit 1
      done
  )  
  done
     
fi

exit 0;
