#!/usr/bin/python

import os, argparse
import sys

def main(wav_path,save_dir):

    text = []; wavscp = []; utt2spk = []; text_norepeat = []
    audio_format = wav_path.split('.')[-1]
    utt_id = wav_path.split('.'+audio_format)[0].split('/')[-1]
 
    utt2spk = utt_id + ' ' + utt_id
    wavscp = utt_id + ' sox --norm ' + wav_path +' -G -t wav -r 16000 -c 1 - remix 1 |'
    text = utt_id
        
    with open(os.path.join(save_dir,'text'),'w') as wt, open(os.path.join(save_dir,'wav.scp'),'w') as ww, open(os.path.join(save_dir,'utt2spk'),'w') as wu:                
        wt.write(text + '\n')
        wu.write(utt2spk+ '\n')
        ww.write(wavscp + '\n')
        
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("wav_path", type=str, help="path to audio")
    parser.add_argument("save_dir", type=str, help="path to save the data files")

    args = parser.parse_args()

    wav_path = args.wav_path
    save_dir = args.save_dir
    main(wav_path,save_dir)        
