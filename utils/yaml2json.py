import argparse
import yaml
import json


def yaml2json(yaml_file, json_file):

    with open(yaml_file, 'r') as file:
        configuration = yaml.safe_load(file)

    with open(json_file, 'w') as json_file:
        json.dump(configuration, json_file, indent=2)


def main():
    argparser = argparse.ArgumentParser()
    argparser.add_argument('-i', '--input-file', required=True,
                        help='path to the .yaml file')
    argparser.add_argument('-o', '--output-file', required=True,
                        help='path to the output .json file')
    args = argparser.parse_args()

    yaml2json(args.input_file, args.output_file)

if __name__ == '__main__':
    main()
