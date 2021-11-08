from kaldiio import ReadHelper
import numpy as np
import argparse

def main(args):

    phone_post_dir = args.phone_post_dir
    output_dir = args.output_dir

    phone_posteriorgram = 'scp:' + phone_post_dir + '/phone_post.1.scp'
   
    with ReadHelper(phone_posteriorgram) as reader:
        for key, array in reader:
            array = np.asarray(array)

    np.save(output_dir + '/phone_post.npy',array)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("phone_post_dir", type=str, help="Path where the phoneme posteriorgrams are located")
    parser.add_argument("output_dir", type=str, help="Path to store phoneme posteriorgrams as np.array (.npy)")

    args = parser.parse_args()
    main(args)
