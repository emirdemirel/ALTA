#!/bin/bash

#adapted from ami and chime5 dict preparation script
#Author: Gerardo Roa

# Begin configuration section.
words=5000
# End configuration section

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. utils/parse_options.sh || exit 1;

# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt

mkdir -p data



dir=data/local/dict
mkdir -p $dir

echo "$0: Getting CMU dictionary"
if [ ! -f $dir/cmudict.done ]; then
  [ -d $dir/cmudict ] && rm -rf $dir/cmudict
  svn co https://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict $dir/cmudict
  touch $dir/cmudict.done
fi

echo "$0: Preparing files in $dir"
# Silence phones
for w in SIL SPN; do echo $w; done > $dir/silence_phones.txt
echo SIL > $dir/optional_silence.txt


# For this setup we're discarding stress.
cat $dir/cmudict/cmudict-0.7b.symbols | \
  perl -ne 's:[0-9]::g; s:\r::; print lc($_)' | \
  tr a-z A-Z | \
  sort -u > $dir/nonsilence_phones.txt

# An extra question will be added by including the silence phones in one class.
paste -d ' ' -s $dir/silence_phones.txt > $dir/extra_questions.txt


grep -v ';;;' $dir/cmudict/cmudict-0.7b |\
  uconv -f latin1 -t utf-8 -x Any-Lower |\
  perl -ne 's:(\S+)\(\d+\) :$1 :; s:  : :; print;' |\
  perl -ne '@F = split " ",$_,2; $F[1] =~ s/[0-9]//g; print "$F[0] $F[1]";' \
  > $dir/lexicon1_raw_nosil.txt || exit 1;


# Add prons for laughter, noise, oov
for w in `grep -v sil $dir/silence_phones.txt`; do
  echo "[$w] $w"
done | cat - $dir/lexicon1_raw_nosil.txt > $dir/lexicon2_raw.txt || exit 1;


# we keep all words from the cmudict in the lexicon
# might reduce OOV rate on dev and test
cat $dir/lexicon2_raw.txt  \
   <( echo "mm m"
      echo "<unk> spn" \
    )  | sed 's/[\t ]/\t/' | tr a-z A-Z  | sort -u > $dir/iv_lexicon.txt


cat data/local/corpus.txt  | \
  awk '{for (n=1;n<=NF;n++){ count[$n]++; } } END { for(n in count) { print count[n], n; }}' | \
  sort -nr > $dir/word_counts_b


# Select the N numbers of words increasingly in order to select all the words with same count

vocab_size=0
start_line=3  #  first two are <s> and </s>
touch $dir/word_list

while [ "$vocab_size" -le "$words" ]; do
    current_count=`sed "${start_line}q;d" $dir/word_counts_b | awk '{print $1}'`
    cat $dir/word_counts_b | grep "^$current_count " | awk '{print $2}' >> $dir/word_list
    vocab_size=`cat $dir/word_list | wc -l`
    start_line=$((vocab_size + 1 ))
done


head -n $vocab_size $dir/word_counts_b > $dir/word_counts
sort -u $dir/word_list > $dir/word_list_sorted


awk '{print $1}' $dir/iv_lexicon.txt | \
  perl -e '($word_counts)=@ARGV;
   open(W, "<$word_counts")||die "opening word-counts $word_counts";
   while(<STDIN>) { chop; $seen{$_}=1; }
   while(<W>) {
     ($c,$w) = split;
     if (!defined $seen{$w}) { print; }
   } ' $dir/word_counts > $dir/oov_counts.txt


echo "*Highest-count OOVs (including fragments) are:"
head -n 10 $dir/oov_counts.txt
echo "*Highest-count OOVs (excluding fragments) are:"
grep -v -E '^-|-$' $dir/oov_counts.txt | head -n 10 || true


echo "*Training a G2P and generating missing pronunciations"
mkdir -p $dir/g2p/

if [ -e $dir/g2p/g2p.fst ]
then
    echo "$0: Phonetisaurus exist. $dir/g2p/g2p.fst will be used"
else
    phonetisaurus-align --input=$dir/iv_lexicon.txt --ofile=$dir/g2p/aligned_lexicon.corpus
    ngram-count -order 4 -kn-modify-counts-at-end -ukndiscount\
      -gt1min 0 -gt2min 0 -gt3min 0 -gt4min 0 \
      -text $dir/g2p/aligned_lexicon.corpus -lm $dir/g2p/aligned_lexicon.arpa
    phonetisaurus-arpa2wfst --lm=$dir/g2p/aligned_lexicon.arpa --ofile=$dir/g2p/g2p.fst
fi

awk '{print $2}' $dir/oov_counts.txt > $dir/oov_words.txt
phonetisaurus-apply --nbest 2 --model $dir/g2p/g2p.fst --thresh 5 --accumulate \
  --word_list $dir/oov_words.txt > $dir/oov_lexicon.txt


## We join pronunciation with the selected words to create lexicon.txt
cat $dir/oov_lexicon.txt $dir/iv_lexicon.txt | sort -u > $dir/lexicon1_plus_g2p.txt
join $dir/lexicon1_plus_g2p.txt $dir/word_list_sorted > $dir/lexicon.txt

echo "<UNK> SPN" >> $dir/lexicon.txt

## The next section is again just for debug purposes
## to show words for which the G2P failed
rm -f $dir/lexiconp.txt 2>null; # can confuse later script if this exists.
awk '{print $1}' $dir/lexicon.txt | \
  perl -e '($word_counts)=@ARGV;
   open(W, "<$word_counts")||die "opening word-counts $word_counts";
   while(<STDIN>) { chop; $seen{$_}=1; }
   while(<W>) {
     ($c,$w) = split;
     if (!defined $seen{$w}) { print; }
   } ' $dir/word_counts > $dir/oov_counts.g2p.txt

echo "*Highest-count OOVs (including fragments) after G2P are:"
head -n 10 $dir/oov_counts.g2p.txt

utils/validate_dict_dir.pl $dir
exit 0;
