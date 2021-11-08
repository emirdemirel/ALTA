import json
import argparse
from os.path import join, exists, isfile
from os import makedirs, listdir
import re
import hashlib


class DataSet:
    def __init__(self, name, workspace):
        self.segments = []
        self.spk2gender = []
        self.text = []
        self.utt2spk = []
        self.wavscp = []
        self.workspace = join(workspace, name)

    def add_utterance(self, utt, recording):

        text = utt["text"]
        arrangement, performance, country, gender, user = recording[:-4].split("-")
        insensitive_none = re.compile(re.escape('none'), re.IGNORECASE)
        spk = "{}{}".format(insensitive_none.sub('', gender).upper(), insensitive_none.sub('', user))
        rec_id = recording[:-4].replace('None',"")
        utt_id = "{}-{}-{}-{}-{}-{:03}".format(spk, arrangement, performance, country, gender.upper(), utt["index"])
        g = utt_id[0]      
        if '-'+g+'-' not in rec_id:
            print(spk)
            print(rec_id)
            print(g)
        start = utt["start"]
        end = utt["end"]
        wavpath = join(country, "{}{}".format(country, "Vocals"), recording)
        gender = gender.replace('none',"")

        self._add_segment(utt_id, rec_id, start, end)
        self._add_spk2gender(spk, gender)
        self._add_text(utt_id, text)
        self._add_utt2spk(utt_id, spk)
        self._add_wavscp(rec_id, wavpath)
      

         
    def _add_segment(self, utt_id, rec_id, start, end):
        self.segments.append("{} {} {:.3f} {:.3f}".format(utt_id, rec_id, start, end))

    def _add_spk2gender(self, spk, gender):
        gender = gender.lower().replace('none',"")
        self.spk2gender.append("{} {}".format(spk, gender))

    def _add_text(self, utt_id, text):
        self.text.append("{} {}".format(utt_id, text))

    def _add_utt2spk(self, utt_id, spk):
        self.utt2spk.append("{} {}".format(utt_id, spk))

    def _add_wavscp(self, rec_id, wavpath):
        self.wavscp.append("{} sox wav/{} -G -t wav -r 16000 -c 1 - remix 1 |".format(rec_id, wavpath))

    def list2file(self, outfile, list_data):
        list_data = list(set(list_data))
        with open(outfile, "w") as f:
            for line in list_data:
                f.write("{}\n".format(line))

    def save(self):
        if not exists(self.workspace):
            makedirs(self.workspace)
        self.list2file(join(self.workspace, "spk2gender"), sorted(self.spk2gender))
        self.list2file(join(self.workspace, "text"), sorted(self.text))
        self.list2file(join(self.workspace, "wav.scp"), sorted(self.wavscp))
        self.list2file(join(self.workspace, "utt2spk"), sorted(self.utt2spk))
        self.list2file(join(self.workspace, "segments"), sorted(self.segments))


def read_json(filepath):
    try: 
        with open(filepath) as data_file:
            data = json.load(data_file)
    except json.decoder.JSONDecodeError:
        data = []
    return data


def map_rec2chec(db_path, countries):
    rec2chec = {}
    for country in countries:
        recordings = [f for f in listdir(join(db_path, country, country + "Vocals")) if f.endswith(".m4a")]
        for record in recordings:
            rec2chec[hashlib.md5(open(join(db_path, country, country + "Vocals", record), 'rb').read()).hexdigest()] = record         
    return rec2chec


def main(args):
    db_path = args.db_path
    workspace = args.workspace
    utts_path = args.utterances
    dset = args.dset

    countries = ["GB","US", "AU",'AE', 'AR', 'BR', 'CL', 'CN', 'DE', 'ES', 'FR', 'HU',
                  'ID', 'IN', 'IQ', 'IR', 'IT', 'JP', 'KR', 'MX', 'MY',
                  'NO', 'PH', 'PT', 'RU', 'SA', 'SG', 'TH', 'VN', 'ZA']

    performances = map_rec2chec(db_path, countries)
    utterances = read_json(utts_path)
    dataset = DataSet(dset, workspace)

    for utt in utterances:
        dataset.add_utterance(utt, performances[utt["wavfile"]])

    dataset.save()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("workspace", type=str, help="Path where the output files will be saved")
    parser.add_argument("db_path", type=str, help="Path to DAMP 300x30x2 database")
    parser.add_argument("utterances", type=str, help="Path to utterance details in json format",
                        default="metadata.json")
    parser.add_argument("dset", type=str, help="Name of the dataset")

    args = parser.parse_args()
    main(args)
