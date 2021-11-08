#!/bin/bash

set -e # exit on error

# Begin configuration section

nj=40

stage=1
chain_stage=1
train_stage=-10

decode_nj=1

#DECLARE WHERE YOUR DAMP AND DALI DATA IS LOCATED!!!!
datadir_damp=
datadir_dali=

pretrained_model=


export CUDA_VISIBLE_DEVICES=1,2,3

echo "Linking data to local directories"
mkdir -p wav
[[ ! -L "wav/damp" ]] && ln -s $datadir_damp
[[ ! -L "wav/dali" ]] && ln -s $datadir_dali

echo "Using steps and utils from WSJ recipe"
[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils
[[ ! -L "rnnlm" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/rnnlm


# End configuration section
. ./utils/parse_options.sh

. ./path.sh
. ./cmd.sh



trainset=train_damp_music # At first, we train the GMM-HMM model on DAMP dataset only (until stage 9). 
                          # Once we generate alignments using the lexicon with estimated pronunciation
                          # probabilities, we retrain another GMM-HMM model on both 'train_damp' and 'train_dali'.
                          # The LFMMI training is done on the combination of these train sets.
                          # For this recipe, we apply the music informed silence tagging on training sets.
devsets="dev_damp dev_dali"
test_sets="test_damp dali_talt jamendo_poli"

# This script also needs the phonetisaurus g2p, srilm, sox
#./local/check_tools.sh || exit 1


chain_affix=_mstrenet
lang_affix=_music


echo; echo "===== Starting at  $(date +"%D_%T") ====="; echo

mfccdir=mfcc

affix=_music      # Label for music informed silence tagging

if [ $stage -le 1 ]; then
    echo
    echo "============================="
    echo "---- DATA PREPROCESSING ----"
    echo "=====  $(date +"%D_%T") ====="
    mkdir -p data/local/dict${affix}
    cp conf/corpus_v2.txt  data/local/corpus.txt  # Corpus.txt for language model that includes lyrics from conf/corpus_v1.txt and train_dali
    # Here, we add <music> phoneme in the class set and the relevant entry in the pronunciation dictionary
    local/prepare_dict_music.sh --words 30000 --affix ${affix}   
    # Prepare necessary files for creating language FST.
    utils/prepare_lang.sh --share-silence-phones true data/local/dict${affix} "<UNK>" data/local/lang${affix} data/lang${affix}
    
fi


if [ $stage -le 2 ]; then
    echo
    echo "============================="
    echo "---- BUILDING THE LANGUAGE MODEL ----"
    echo "=====  $(date +"%D_%T") ====="
    # Constructing the 4-gram MaxEnt language model
    local/train_lms_srilm.sh \
        --train-text data/local/corpus_en.txt \
        --oov-symbol "<UNK>" --words-file data/lang$affix/words.txt \
        data/ data/srilm$affix
    # Compiles G for DSing 4-g LM
    utils/format_lm.sh  data/lang$affix data/srilm$affix/best_4gram.gz data/local/dict${affix}/lexicon.txt data/lang_4G$affix

fi


if [[ $stage -le 3 ]]; then

  echo
  echo "============================="
  echo "---- MFCC FEATURES EXTRACTION ----"
  echo "=====  $(date +"%D_%T") ====="

  for datadir in train_damp_music train_dali_music $test_sets; do
    echo; echo "---- ${datadir}"
    utils/fix_data_dir.sh data/$datadir
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/$datadir exp$affix/make_mfcc/$datadir $mfccdir
    steps/compute_cmvn_stats.sh data/${datadir}
    utils/fix_data_dir.sh data/$datadir
  done
fi


if [[ $stage -le 4 ]]; then

    echo
    echo "============================="
    echo "TRAIN GMM-HMM : Mono - MONOPHONE"
    echo
    echo "=====  $(date +"%D_%T") ====="

    steps/train_mono.sh --nj $nj --cmd "$train_cmd" --totgauss 2000 --boost-silence 1.25 \
      --num_iters 40 data/${trainset} data/lang$lang_affix exp$affix/mono

    steps/align_si.sh --nj $nj --cmd "$train_cmd" --beam 50 --retry_beam 700 \
      data/${trainset} data/lang$lang_affix exp$affix/mono exp$affix/mono_ali

    utils/mkgraph.sh data/lang_4G$lang_affix exp$affix/mono exp$affix/mono/graph

fi


if [[ $stage -le 5 ]];then

    echo 
    echo "============================="
    echo "TRAIN GMM-HMM : Tri 1 - DELTA-BASED TRIPHONES"
    echo "=====  $(date +"%D_%T") ====="

    steps/train_deltas.sh  --cmd "$train_cmd" --boost_silence 1.25 --beam 50 --retry_beam 700 4000 24000 \
      data/${trainset} data/lang$lang_affix exp$affix/mono_ali exp$affix/tri1

    steps/align_si.sh --nj $nj --cmd "$train_cmd" --beam 50 --retry_beam 700  \
     data/${trainset} data/lang$lang_affix exp$affix/tri1 exp$affix/tri1_ali

    utils/mkgraph.sh data/lang_4G$lang_affix exp$affix/tri1 exp$affix/tri1/graph
      

fi


if [[ $stage -le 6 ]];then

    echo
    echo "============================="    
    echo "TRAIN GMM-HMM : Tri 2 - LDA-MLLT TRIPHONES"
    echo "=====  $(date +"%D_%T") ====="

    steps/train_lda_mllt.sh --cmd "$train_cmd" --beam 50 --retry_beam 700 5000 40000 \
      data/${trainset} data/lang$lang_affix exp$affix/tri1_ali exp$affix/tri2b

    steps/align_si.sh --nj $nj --cmd "$train_cmd" --beam 50 --retry_beam 700  \
      data/${trainset} data/lang$lang_affix exp$affix/tri2b exp$affix/tri2b_ali
      

fi



if [[ $stage -le 8 ]];then

    echo
    echo "TRAIN GMM-HMM :  Tri 3 - SAT TRIPHONES"
    echo "=====  $(date +"%D_%T") ====="
   
    steps/train_sat.sh --cmd "$train_cmd" --beam 40 --retry_beam 100 6000 70000 \
      data/${trainset} data/lang$lang_affix exp$affix/tri2b_ali exp$affix/tri3b

    utils/mkgraph.sh data/lang_4G$lang_affix exp$affix/tri3b exp$affix/tri3b/graph
   
fi


if [[ $stage -le 9 ]]; then
    echo
    echo "============================="
    echo "------- DECODE USING TRIPHONE + SAT (TRI3B) MODEL --------"
    echo "=====  $(date +"%D_%T") ====="
    echo
    for datadir in $test_sets ; do
      steps/decode_fmllr.sh --config conf/decode.config --nj 9 --cmd "$decode_cmd" \
        --scoring-opts "--min-lmwt 10 --max-lmwt 20" --num-threads 4 --beam 40 \
        exp$affix/tri3b/graph data/${datadir} exp$affix/tri3b/decode_${datadir}
    done
fi



if [[ $stage -le 10 ]]; then

    echo
    echo "============================="
    echo "------- COMPUTING PRONUNCIATION PROBABILITIES --------"
    echo "=====  $(date +"%D_%T") ====="

  # Estimate pronunciation and silence probabilities.

  # Silence probability for normal lexicon.
  steps/get_prons.sh --cmd "$train_cmd" \
    data/${trainset} data/lang_4G$affix exp$affix/tri3b || exit 1;
  utils/dict_dir_add_pronprobs.sh --max-normalize true data/local/dict${affix} \
    exp${affix}/tri3b/pron_counts_nowb.txt exp${affix}/tri3b/sil_counts_nowb.txt \
    exp${affix}/tri3b/pron_bigram_counts_nowb.txt data/local/dict${affix}_prons || exit 1
    echo
    echo "============================="
    echo "------- CREATING THE LANGUAGE MODEL WITH PRONUNCIATION PROBABILITIES --------"
    echo "=====  $(date +"%D_%T") ====="
  utils/prepare_lang.sh data/local/dict${affix}_prons \
    "<UNK>" data/local/lang${affix} data/lang${affix}_prons || exit 1;

  mkdir -p data/lang_4G${affix}_prons
  cp -r data/lang${affix}_prons/* data/lang_4G${affix}_prons/ || exit 1;
  rm -rf data/local/lang_tmp
  cp data/lang_4G${affix}/G.* data/lang_4G${affix}_prons/

fi


if [ $stage -le 11 ]; then

    echo
    echo "TRAIN (ANOTHER) SAT TRIPHONES GMM-HMM WITH PRONUNCIATION PROBABILITIES:  Tri3b - PRONS "
    echo "=====  $(date +"%D_%T") ====="

    #Combine DAMP and DALI data and retrain the final GMM-HMM model
    trainset=train_damp_dali_music
    ./utils/combine_data_dir.sh $trainset data/train_damp_music data/train_dali_music
    
    #Generate alignments for the combined train set.
    steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" --beam 40 --retry_beam 300 \
      data/${trainset} data/lang${affix}_prons exp$affix/tri3b exp$lang_affix/tri3b_ali_prons
   
    steps/train_sat.sh --cmd "$train_cmd" --beam 20 --retry_beam 100 6000 70000 \
      data/${trainset} data/lang${lang_affix}_prons exp$affix/tri3b_ali_prons exp$affix/tri3b_prons

    utils/mkgraph.sh data/lang_4G${affix}_prons exp$affix/tri3b_prons exp$affix/tri3b_prons/graph
   
    echo
    echo "------ END OF GMM-HMM TRAINING --------"
    echo "=====  $(date +"%D_%T") ====="
fi

if [[ $stage -le 12 ]]; then
    echo
    echo "============================="
    echo "------- DECODE USING TRIPHONE + SAT (TRI3B) MODEL WITH PRON. PROBS.--------"
    echo "=====  $(date +"%D_%T") ====="
    echo
    for datadir in $test_sets ; do
      steps/decode_fmllr.sh --config conf/decode.config --nj 9 --cmd "$decode_cmd" \
        --scoring-opts "--min-lmwt 10 --max-lmwt 20" --num-threads 4 --beam 30 \
        exp$affix/tri3b_prons/graph data/${datadir} exp$affix/tri3b_prons/decode_${datadir}
    done

fi


trainset=train_damp_dali_music
if [[ $stage -le 13 ]]; then
    echo
    echo "=================="
    echo "----- MSTRE-NET: TRAINING DNN-HMM BASED ON LFMMI OBJECTIVE -----"
    echo "=====  $(date +"%D_%T") ====="
    echo

    local/chain/run_multistream.sh --affix ${affix} --nnet3_affix ${chain_affix} --chain_affix ${chain_affix} \
        --stage ${chain_stage} --train_stage ${train_stage} --train_set ${trainset} --test_sets ${test_sets}
fi


if [[ $stage -le 14 ]]; then
    echo
    echo "=================="
    echo "----- INFERENCE WITH A PRETRAINED MODEL (MONOPHONIC - SINGLE STREAM A.M.) -----"
    echo "=====  $(date +"%D_%T") ====="
    echo

   
fi


echo
echo "=====  $(date +"%D_%T") ====="
echo "===== PROCESS ENDED ====="
echo

exit 1
