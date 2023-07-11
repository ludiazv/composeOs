import argparse
import os
import sys
import yaml
import subprocess
import shutil
import re



CONTAINER_NAME = "composeos_build"
CONTAINER_IMAGE = "crops/poky:ubuntu-20.04"
COMPOSEOS_YML  = "composeos.yml"

DOWNLOAD_DIR = "downloads"
STATE_DIR = "sstate-cache"


''' Some utility functions
'''


def mkdir_p(d):

    os.makedirs(d, exist_ok=True)


def die(msg):

    print(msg)
    sys.exit(1)

def ask(msg):
    i=input(f"{msg} [y/N]?")
    return i.lower() == 'y'


def rmdir(d):
    if os.path.isdir(d):
        shutil.rmtree(d,ignore_errors=True)

# Assets

def checkout_repo(pwd, rep):

    if 'name' in rep and 'repo' in rep and 'dir' in rep and 'branch' in rep:
        print(f"Processing {rep['name']}...")
        dst = os.path.join(pwd, rep['dir'])
        if os.path.isdir(dst):
            print(f"{rep['name']}: directory {dst} already exists, try to fetch changes...")
            os.chdir(dst)
            subprocess.run(['git', 'checkout', 'master'])
            subprocess.run(['git', 'fetch', '-v'])
            subprocess.run(['git', 'pull'])
            os.chdir(pwd)
        else:
            print(f"{rep['name']}: Cloning to {dst}")
            subprocess.run(['git', 'clone', rep['repo'], rep['dir']])
        
        print(f"{rep['name']}: checking out desired branch '{rep['branch']}'")
        os.chdir(dst)
        subprocess.run(['git', 'checkout', rep['branch']])
        subprocess.run(['git', 'fetch','-v'])
        subprocess.run(['git', 'pull'])
        os.chdir(pwd)

    else:
        die(f"Malformed repo entry:{rep}")


def assets(arg, conf):
    pwd = os.getcwd()
    print("Preparing assets for ComposeOS compilation...")
    print(f"Working on cwd={pwd}")
    print(f"Creating download and cache directories... {DOWNLOAD_DIR} / {STATE_DIR}")
    mkdir_p(DOWNLOAD_DIR)
    mkdir_p(STATE_DIR)

    if 'crops_container' in conf:
        print(f"Pulling CROPS builder {conf['crops_container']}...")
        subprocess.run(['docker', 'pull', conf['crops_container']])
    else:
        die("Malformed 'crops_container' entry in configuration yml")

    if 'repos' in conf and isinstance(conf['repos'], list):
        for r in conf['repos']:
            checkout_repo(pwd, r)

    else:
        die("Malformed 'repos' list in configuration yml")


def clean_board(b):
    pwd = os.getcwd()
    p = os.path.join(pwd, b)
    print(f"Cleaning board {b} by removing {p}....", end='')
    rmdir(p)
    print("OK")


def clean(arg, conf):
    if not ask("This will remove all temporary files. Are you sure (y/N)?"):
        return

    print("Cleanning....")
    if arg.board:
        clean_board(arg.board)
    else:
        print("clean docker")
        print("TODO")
        print("donwloads and state...", end='')
        rmdir(DOWNLOAD_DIR)
        rmdir(STATE_DIR)
        print("Done")
        print("Cleaning all defined boards...")
        for b in conf['boards'].keys():
            clean_board(b)
        
        print("Outputs...")
        rmdir("output_images")

def config_board(board, info):

    if 'machine' in info and 'local' in info and 'layers' in info:
        machine = info['machine']
        pwd = os.getcwd()
        conf_dir = os.path.join(pwd, board, 'conf')
        local_file = os.path.join(conf_dir, 'local.conf')
        local_fileb = os.path.join(conf_dir, 'local.conf_orig')
        layer_file = os.path.join(conf_dir, 'bblayers.conf')
        layer_fileb = os.path.join(conf_dir, 'bblayers.conf_orig')

        # bootstrap board dir if needed
        if not os.path.isdir(conf_dir) or not os.path.isfile(local_fileb) or not os.path.isfile(layer_fileb):
            print("bootstrap build directory...", end='')
            cmd = f"docker run -ti --rm --name {CONTAINER_NAME}_bs -v{pwd}:{pwd} --workdir={pwd} {CONTAINER_IMAGE} bash -c 'source poky/oe-init-build-env {board}; bitbake --version'"
            res = subprocess.run(cmd, shell=True)
            if res.returncode == 0:
                shutil.copy(local_file, local_fileb)
                shutil.copy(layer_file, layer_fileb)
            else:
                die(f"failed to bootstrap build directory for {board}")

            print(f"{board} build directory created")

        # Process local and layers check
        if not os.path.isdir(conf_dir) or not os.path.isfile(local_fileb) or not os.path.isfile(layer_fileb):
            die(f"build dir for board {board} not valid")

        # Process local
        print(f"Processing local.conf for {board}...", end='')
        with open(local_fileb, 'r') as f:
            src = f.readlines()

        with open(local_file, 'w') as f:
            print(f"# Created for composeOS for board {board}", file=f)
            for li in src:
                # remove comments lines black lines and package_classes
                if re.match(r"\A\s*#.*", li) or re.match(r"\A\s+\Z", li):
                    continue
                elif 'PACKAGE_CLASSES' in li:
                    continue
                else:
                    print(li, file=f, end="")

            print(f'MACHINE = "{machine}"', file=f)
            print('SSTATE_DIR ?= "${TOPDIR}/../' + STATE_DIR + '"', file=f)
            print('DL_DIR ?= "${TOPDIR}/../' + DOWNLOAD_DIR + '"', file=f)
            for k, v in info['local'].items():
                print(v, file=f)

        print("OK")

        # process bblayers
        print(f"Processing bblayers.conf for {board}...", end='')
        with open(layer_fileb, 'r') as f:
            src = f.read()

        nl = map(lambda x: "${TOPDIR}/../"+x, list(info['layers'].values()))
        new_layers = " \\ \n".join(nl)
        new_layers = "BBLAYERS ?= \" \\\n" + new_layers + " \\\n  \"\n"
        new_layers = "# BBLAYERS generated by composeos.py\n" + new_layers

        new_bblayers = re.sub(r'\s*BBLAYERS[\s\?]*=\s*\"\s\\\n[\s\w\\\n/\-]*\"', f"\n\n{new_layers}\n\n", src)

        with open(layer_file, 'w') as f:
            print(new_bblayers, file=f)

        print("OK")

    else:
        die(f"Maformed board profile for {board}")


def config(arg, conf):

    if arg.all:
        print("CONFIG on all boards started")
        for b, v in conf['boards'].items():
            config_board(b, v)
    else:
        if arg.board is not None:
            if arg.board in conf['boards']:
                config_board(arg.board, conf['boards'][arg.board])
            else:
                die(f"board '{arg.board}' does not exists in config yml file")
        else:
            die(f"config requires a board via --board <name> or --all for all boards")


def build_board(board, info, debug=True):
    pwd = os.getcwd()
    vol = pwd
    extra_cmd=""
    # For debug contributions comment TODO
    vol = os.path.join(os.environ.get("HOME"), 'projects')
    #extra_cmd="bitbake -c cleansstate bootfiles ; bitbake bootfiles;"
    # debug section
    print(f"pwd -> {pwd} | vol -> {vol}")
    if debug:
        target = "cos-image-debug"
        fname = "composeos-deb"
        compressor = "gzip"
        c_level = "-4"
    else:
        target = "cos-image"
        fname = "composeos"
        compressor = "xz"
        c_level = "-9"

    cmd = f"docker run -ti --rm --name {CONTAINER_NAME} -v{vol}:{vol} --workdir={pwd} {CONTAINER_IMAGE} bash -c 'source poky/oe-init-build-env {board}; {extra_cmd} bitbake {target}'"
    result = subprocess.run(cmd, shell=True)

    if result.returncode == 0:
        img=map(lambda x: ( f"{target}-{info['machine']}.{x}", x ), info['images'])
        print("Build done now copying images ...", end='', flush=True)
        for i, ext in img:
            src = os.path.join(board, 'tmp', 'deploy', 'images', info['machine'], i)
            dst = os.path.join(os.getcwd(), 'output_images', f"{fname}-{info['machine']}.{ext}")
            print(f"[{dst}]", end="", flush=True)
            subprocess.run(['cp', src, dst])
            if not ('.xz' in i or '.bz2' in i or '.gz' in i):
                print("Z", end="", flush=True)
                subprocess.run([compressor, c_level, dst])
        print("OK")

    else:
        die(f"{board} failed build")
        



def build(arg, conf):

    mkdir_p(os.path.join(os.getcwd(), "output_images"))

    if arg.all:
        print("BUILD for all boards started")
        for b, v in conf['boards'].items():
            build_board(b, v)
            
    elif arg.board is not None:
        if arg.board in conf['boards']:
            build_board(arg.board, conf['boards'][arg.board])
        else:
            die(f"board '{arg.board}' does not exists in config yml file")
    else:
        die(f"config requires a board via --board <name> or --all for all boards")


''' Main program
'''


def main():

    parser = argparse.ArgumentParser('composeOs builder utility')
    parser.add_argument("--file", default=COMPOSEOS_YML, help="Name of the configurartion file")
    sparser = parser.add_subparsers(dest='command')
    asset_p = sparser.add_parser("asset", help="Download required layers and create directories")
    clean_p = sparser.add_parser("clean", help="Clean all including docker containers and images")
    conf_p = sparser.add_parser("config", help="Create config files for board (conf/local.conf & conf/bblayers.conf)")
    build_p = sparser.add_parser("build", help="Build composeOS")

    # sub parser options
    clean_p.add_argument("--board", help="Only cleans selected board build directory")
    conf_p.add_argument("--board", help="Only configure selected board", type=str)
    conf_p.add_argument("--all", help="Configure all boards", action="store_true")

    build_p.add_argument("--board", help="Only configure selected board", type=str)
    build_p.add_argument("--all", help="Configure all boards", action="store_true")

    p_args = parser.parse_args()

    # Read configuraton file
    with open(p_args.file, 'r') as f:
        conf = yaml.safe_load(f)
    # print(conf)
    # print(p_args)

    if 'crops_container' in conf:
        global CONTAINER_IMAGE
        CONTAINER_IMAGE = conf['crops_container']

    if p_args.command == 'asset':
        assets(p_args, conf)
    elif p_args.command == 'clean':
        if ask("Clean will remove build data, continue"):
            clean(p_args, conf)
        else:
            print("cancelled")
    elif p_args.command == 'config':
        if 'boards' in conf and isinstance(conf['boards'], dict):
            config(p_args, conf)
        else:
            die("Malformed yml boards field is not a dict")

    elif p_args.command == 'build':
        if 'boards' in conf and isinstance(conf['boards'], dict):
            build(p_args, conf)
        else:
            die("Malformed yml boards field is not a dict")
    
    print('Done!')


# Just the entry point
if __name__ == "__main__":
    main()
