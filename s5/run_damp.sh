#!/bin/bash

# Begin configuration section
nj=40
stage=6
decode_nj=1

. ./path.sh
. ./cmd.sh

set -e # exit on error

# End configuration section


audio_path=$1 

[[ ! -L "wav" ]] && ln -s $audio_path wav
[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils
[[ ! -L "rnnlm" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/rnnlm

. ./utils/parse_options.sh


trainset=train
devset=dev
testset=test


echo; echo "===> START TIME : $(date +"%D_%T") ====="; echo

mfccdir=mfcc

text_corpus=conf/corpus.txt

if [ $stage -le 1 ]; then
    #mkdir -p data/local/dict
    #cp $text_corpus  data/local/corpus.txt  # text corpus for LM
    #local/prepare_dict.sh --words 30000
    utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang

    local/train_lms_srilm.sh \
        --train-text data/local/corpus.txt \
        --dev_text data/dev/text \
        --oov-symbol "<UNK>" --words-file data/lang/words.txt \
        data/ data/srilm

    # Compiles G.fst for 3 & 4 gram LMs
    utils/format_lm.sh  data/lang data/srilm/best_3gram.gz data/local/dict/lexicon.txt data/lang_3G
    utils/format_lm.sh  data/lang data/srilm/best_4gram.gz data/local/dict/lexicon.txt data/lang_4G

fi



if [[ $stage -le 2 ]]; then
  echo "============================="
  echo "---- FEATURE EXTRACTION ($mfccdir) ----"
  echo "=====  $(date +"%D_%T") ====="

  for datadir in $trainset $devset $testset; do
    echo; echo "---- ${datadir}"
    utils/fix_data_dir.sh data/$datadir
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/$datadir exp/make_mfcc/$datadir $mfccdir
    steps/compute_cmvn_stats.sh data/${datadir}
    utils/fix_data_dir.sh data/$datadir
  done

fi

if [[ $stage -le 3 ]]; then

    echo "============================="
    echo "-------- GMM-HMM BOOTSTRAPPING ----"
    echo "=====  $(date +"%D_%T") ====="
    echo
    echo "===> 0) Monophone Model Training"
    echo

    steps/train_mono.sh --nj $nj --cmd "$train_cmd"  \
          data/${trainset} data/lang exp/mono

    steps/align_si.sh --nj $nj --cmd "$train_cmd" \
      data/${trainset} data/lang exp/mono exp/mono_ali

    utils/mkgraph.sh data/lang_4G exp/mono exp/mono/graph

    echo
    echo "===> 1) Triphone Model Training with delta Features"
    echo "=====  $(date +"%D_%T") ====="    

    steps/train_deltas.sh  --cmd "$train_cmd" 2000 15000 \
      data/${trainset} data/lang exp/mono_ali exp/tri1

    steps/align_si.sh --nj $nj --cmd "$train_cmd"  \
     data/${trainset} data/lang exp/tri1 exp/tri1_ali
      
    echo
    echo "===> 2) Triphone Model Training with LDA-MLLT Features"
    echo "=====  $(date +"%D_%T") ====="

    steps/train_lda_mllt.sh --cmd "$train_cmd" 2500 20000 \
      data/${trainset} data/lang exp/tri1_ali exp/tri2b

    steps/align_si.sh --nj $nj --cmd "$train_cmd"  \
      data/${trainset} data/lang exp/tri2b exp/tri2b_ali
      
    echo
    echo "===> 3) Triphone Model Training with Singer Adaptive Features"
    echo "=====  $(date +"%D_%T") ====="
   
    steps/train_sat.sh --cmd "$train_cmd" 3000 25000 \
      data/${trainset} data/lang exp/tri2b_ali exp/tri3b

    utils/mkgraph.sh data/lang_4G exp/tri3b exp/tri3b/graph
   
    echo
    echo "------ End Train GMM-HMM --------"
    echo "=====  $(date +"%D_%T") ====="
fi



if [[ $stage -le 4 ]]; then
    echo
    echo "============================="
    echo "------- Lyrics Alignment on $devset and $testset data using GMM-HMM (SAT) model --------"
    echo "=====  $(date +"%D_%T") ====="
    echo

    for dataset in dev test; do
      steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
        data/$dataset data/lang \
        exp/tri3b exp/tri3b_ali_$dataset
    done
fi

if [[ $stage -le 5 ]]; then
    echo
    echo "============================="
    echo "------- Decoding using GMM-HMM (SAT) model --------"
    echo " Note: This should give similar results to th GMM scores in the paper. --------"
    echo "=====  $(date +"%D_%T") ====="
    echo

    steps/decode_fmllr.sh --config conf/decode.config --nj 30 --cmd "$decode_cmd" \
      --scoring-opts "--min-lmwt 10 --max-lmwt 20" --num-threads 4  \
      exp/tri3b/graph data/${devset} exp/tri3b/decode_${devset}

    # Scoring test model with the best
    lmwt=$(cat exp/tri3b/decode_${devset}/scoring_kaldi/wer_details/lmwt)
    wip=$(cat exp/tri3b/decode_${devset}/scoring_kaldi/wer_details/wip)
    steps/decode_fmllr.sh --config conf/decode.config --nj 12 --cmd "$decode_cmd" \
      --scoring-opts "--min_lmwt $lmwt --max_lmwt $lmwt --word_ins_penalty $wip" --num-threads 4  \
      exp/tri3b/graph data/${testset} exp/tri3b/decode_${testset}

fi

train_stage=-10    # Change this if you want to resume neural network training from where you paused
chain_stage=3
if [[ $stage -le 6 ]]; then
    echo
    echo "=================="
    echo "----- Training Neural Networks for the Acoustic Model -----"
    echo "=====  $(date +"%D_%T") ====="
    echo

    local/chain/run_ctdnn_sa.sh --stage $chain_stage --train_stage $train_stage \
      $trainset "$devset $testset"
fi

if [[ $stage -le 7 ]]; then
    echo
    echo "=================="
    echo "----- Decoding the test data using CTDNN_SA Acoustic Model and 4-g MaxEnt LM -----"
    echo "=====  $(date +"%D_%T") ====="
    echo
    chunk_width=140,100,160
    frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
    rm $dir/.error 2>/dev/null || true

    for data in dev test; do
      (
        nspk=$(wc -l <data/${data}_hires/spk2utt)
        for lmtype in 3G 4G; do
          graph_dir=exp/chain_cleaned/ctdnn_sa/graph_${lmtype}
          steps/nnet3/decode.sh \
            --acwt 1.0 --post-decode-acwt 10.0 \
            --frames-per-chunk $frames_per_chunk \
            --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
            --online-ivector-dir exp/nnet_cleaned/ivectors_${data}_hires \
            $graph_dir data/${data}_hires ${dir}/decode_${lmtype}_${data} || exit 1
        done
    )  
    done
fi

if [[ $stage -le 8 ]]; then
    echo
    echo "=================="
    echo "----- RNNLM TRAINING -----"
    echo " (Training is done on training text corpus)"
    echo "=====  $(date +"%D_%T") ====="
    echo
    mkdir -p data/rnnlm
    cat data/$trainset/text data/$devset/text > data/rnnlm/text_rnnlm
    ./local/train_rnnlm.sh --text data/rnnlm/text_rnnlm

fi



if [[ $stage -le 9 ]]; then
    echo
    echo "=================="
    echo "----- (Pruned) LATTICE RESCORING USING RNNLM -----"
    echo "=====  $(date +"%D_%T") ====="
    echo
    # Here we rescore the lattices generated at stage 8
    rnnlm_dir=exp/rnnlm
    ngram_order=4   #You can also try with 3
    lang_dir=data/lang_chain
    for dataset in dev test; do
      data_dir=data/${dataset}_hires
      decoding_dir=exp/chain_cleaned/ctdnn_sa/decode_${ngram_order}G_${dataset}
      output_dir=${decoding_dir}_rnnlm
      rnnlm/lmrescore_pruned.sh \
        --cmd "$decode_cmd --mem 4G" \
        --weight 0.5 --max-ngram-order $ngram_order \
        $lang_dir $rnnlm_dir $data_dir $decoding_dir \
        $output_dir
    done
fi


if [[ $stage -le 17 ]]; then
    echo
    echo "============================="
    echo "------- FINAL SCORES --------"
    echo "=====  $(date +"%D_%T") ====="
    echo

    for x in `find exp/* -name "best_wer"`; do
        cat $x | grep -v ".si"
    done
fi

echo
echo "=====  $(date +"%D_%T") ====="
echo "===== PROCESS ENDED ====="
echo

exit 1
