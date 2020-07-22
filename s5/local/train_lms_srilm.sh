#!/bin/bash
# Copyright (c) 2017  Johns Hopkins University (Author: Yenda Trmal, Shinji Watanabe)
# Apache 2.0

export LC_ALL=C

# Begin configuration section.
words_file=
train_text=
dev_text=
oov_symbol="<UNK>"
# End configuration section

echo "$0 $@"

[ -f path.sh ]  && . ./path.sh
. ./utils/parse_options.sh || exit 1

echo "-------------------------------------"
echo "Building an SRILM language model     "
echo "-------------------------------------"

if [ $# -ne 2 ] ; then
  echo "Incorrect number of parameters. "
  echo "Script has to be called like this:"
  echo "  $0 [switches] <datadir> <tgtdir>"
  echo "For example: "
  echo "  $0 data data/srilm"
  echo "The allowed switches are: "
  echo "    words_file=<word_file|>        word list file -- data/lang/words.txt by default"
  echo "    train_text=<train_text|>       data/train/text is used in case when not specified"
  echo "    dev_text=<dev_text|>           last 10 % of the train text is used by default"
  echo "    oov_symbol=<unk_sumbol|<UNK>>  symbol to use for oov modeling -- <UNK> by default"
  exit 1
fi

datadir=$1
tgtdir=$2

##End of configuration
loc=`which ngram-count`;
if [ -z $loc ]; then
  echo >&2 "You appear to not have SRILM tools installed, either on your path,"
  echo >&2 "Use the script \$KALDI_ROOT/tools/install_srilm.sh to install it."
  exit 1
fi

# Prepare the destination directory
mkdir -p $tgtdir

for f in $words_file $train_text $dev_text; do
  [ ! -s $f ] && echo "No such file $f" && exit 1;
done

[ -z $words_file ] && words_file=$datadir/lang/words.txt
if [ ! -z "$train_text" ] && [ -z "$dev_text" ] ; then
  nr=`cat  $train_text | wc -l`
  nr_dev=$(($nr / 10 ))
  nr_train=$(( $nr - $nr_dev ))
  orig_train_text=$train_text
  head -n $nr_train $train_text > $tgtdir/train_text
  tail -n $nr_dev $train_text > $tgtdir/dev_text

  train_text=$tgtdir/train_text
  dev_text=$tgtdir/dev_text
  echo "Using words file: $words_file"
  echo "Using train text: 9/10 of $orig_train_text"
  echo "Using dev text  : 1/10 of $orig_train_text"
elif [ ! -z "$train_text" ] && [ ! -z "$dev_text" ] ; then
  echo "Using words file: $words_file"
  echo "Using train text: $train_text"
  echo "Using dev text  : $dev_text"
  train_text=$train_text
  dev_text=$dev_text
else
  train_text=$datadir/train/text
  dev_text=$datadir/dev2h/text
  echo "Using words file: $words_file"
  echo "Using train text: $train_text"
  echo "Using dev text  : $dev_text"

fi

[ ! -f $words_file ] && echo >&2 "File $words_file must exist!" && exit 1
[ ! -f $train_text ] && echo >&2 "File $train_text must exist!" && exit 1
[ ! -f $dev_text ] && echo >&2 "File $dev_text must exist!" && exit 1


# Extract the word list from the training dictionary; exclude special symbols
sort $words_file | awk '{print $1}' | grep -v '\#0' | grep -v '<eps>' | grep -v -F "$oov_symbol" > $tgtdir/vocab
if (($?)); then
  echo "Failed to create vocab from $words_file"
  exit 1
else
  # wc vocab # doesn't work due to some encoding issues
  echo vocab contains `cat $tgtdir/vocab | perl -ne 'BEGIN{$l=$w=0;}{split; $w+=$#_; $w++; $l++;}END{print "$l lines, $w words\n";}'`
fi

# corpus file has <s> <\s> tag; remove it
sed -e 's/^\w*\ *//' -e 's/ \+[^ ]\+$//' $train_text | sort -u | \
  perl -ane 'print join(" ", @F[1..$#F]) . "\n" if @F > 1' > $tgtdir/train.txt
if (($?)); then
    echo "Failed to create $tgtdir/train.txt from $train_text"
    exit 1
else
    echo "Removed first and last word (<s> <\s> tags) from every line of $train_text"
    # wc text.train train.txt # doesn't work due to some encoding issues
    echo $train_text contains `cat $train_text | perl -ane 'BEGIN{$w=$s=0;}{$w+=@F; $w--; $s++;}END{print "$w words, $s sentences\n";}'`
    echo train.txt contains `cat $tgtdir/train.txt | perl -ane 'BEGIN{$w=$s=0;}{$w+=@F; $s++;}END{print "$w words, $s sentences\n";}'`
fi

# data/dev/text
cat $dev_text | cut -d ' ' -f 2- > $tgtdir/dev.txt
if (($?)); then
    echo "Failed to create $tgtdir/dev.txt from $dev_text"
    exit 1
else
    echo "Removed first word (uid) from every line of $dev_text"
    # wc text.train train.txt # doesn't work due to some encoding issues
    echo $dev_text contains `cat $dev_text | perl -ane 'BEGIN{$w=$s=0;}{$w+=@F; $w--; $s++;}END{print "$w words, $s sentences\n";}'`
    echo $tgtdir/dev.txt contains `cat $tgtdir/dev.txt | perl -ane 'BEGIN{$w=$s=0;}{$w+=@F;  $s++;}END{print "$w words, $s sentences\n";}'`
fi


if [ ! -z ${LIBLBFGS} ]; then
  #please note that if the switch -map-unk "$oov_symbol" is used with -maxent-convert-to-arpa, ngram-count will segfault
  #instead of that, we simply output the model in the maxent format and convert it using the "ngram"
  echo "-------------------"
  echo "Maxent 3grams"
  echo "-------------------"
  sed 's/'${oov_symbol}'/<unk>/g' $tgtdir/train.txt | \
    ngram-count -lm - -order 3 -text - -vocab $tgtdir/vocab -unk -sort -maxent -maxent-convert-to-arpa|\
    ngram -lm - -order 3 -unk -map-unk "$oov_symbol" -prune-lowprobs -write-lm - |\
    sed 's/<unk>/'${oov_symbol}'/g' | gzip -c > $tgtdir/3gram.me.gz || exit 1

  echo "-------------------"
  echo "Maxent 4grams"
  echo "-------------------"
  sed 's/'${oov_symbol}'/<unk>/g' $tgtdir/train.txt | \
    ngram-count -lm - -order 4 -text - -vocab $tgtdir/vocab -unk -sort -maxent -maxent-convert-to-arpa|\
    ngram -lm - -order 4 -unk -map-unk "$oov_symbol" -prune-lowprobs -write-lm - |\
    sed 's/<unk>/'${oov_symbol}'/g' | gzip -c > $tgtdir/4gram.me.gz || exit 1
else
  echo >&2  "SRILM is not compiled with the support of MaxEnt models."
  echo >&2  "You should use the script in \$KALDI_ROOT/tools/install_srilm.sh"
  echo >&2  "which will take care of compiling the SRILM with MaxEnt support"
  exit 1;
fi


echo "--------------------"
echo "Computing perplexity"
echo "--------------------"
(
  for f in $tgtdir/3gram* ; do ( echo $f; ngram -order 3 -lm $f -unk -map-unk "$oov_symbol" -prune-lowprobs -ppl $tgtdir/dev.txt ) | paste -s -d ' ' ; done
  for f in $tgtdir/4gram* ; do ( echo $f; ngram -order 4 -lm $f -unk -map-unk "$oov_symbol" -prune-lowprobs -ppl $tgtdir/dev.txt ) | paste -s -d ' ' ; done
)  | sort  -r -n -k 15,15g | column -t | tee $tgtdir/perplexities.txt

echo "The perlexity scores report is stored in $tgtdir/perplexities.txt "
echo ""

for best_ngram in {3,4}gram ; do
  outlm=best_${best_ngram}.gz
  lmfilename=$(grep "${best_ngram}" $tgtdir/perplexities.txt | head -n 1 | cut -f 1 -d ' ')
  echo "$outlm -> $lmfilename"
  (cd $tgtdir; rm -f $outlm; ln -sf $(basename $lmfilename) $outlm )
done
