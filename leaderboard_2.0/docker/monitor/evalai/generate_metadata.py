import argparse
import shutil
import os

def main():
    """
    Generate the EvalAI metadata, which is jsut a copy of the agent results
    """
    argparser = argparse.ArgumentParser()
    argparser.add_argument('-f', '--file-path', required=True, help='path to all the files containing the partial results')
    argparser.add_argument('-e', '--endpoint', required=True, help='path to the endpoint containing the joined results')
    args = argparser.parse_args()

    if os.path.exists(args.file_path):
        shutil.copyfile(args.file_path, args.endpoint)
    else:
        print(f"Couldn't generate the metadata, missing input file '{args.file_path}'")

if __name__ == '__main__':
    main()
