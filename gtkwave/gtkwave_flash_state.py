#!/usr/bin/env python3

import sys
import tempfile
import subprocess

states = {
    0: "IDLE",
    1: "CMD",
    2: "ADDR",
    3: "DATA",

    98: "WAIT_ACK",
    99: "WAIT"
}


def main(argv0, *args):
    fh_in = sys.stdin
    fh_out = sys.stdout

    while True:
        l = fh_in.readline()
        if not l:
            return 0

        if "x" in l:
            fh_out.write(l)
            fh_out.flush()
            continue

        state = int(l, 16)
        if state in states:
          fh_out.write("%s\n" % states[state])
        else:
          fh_out.write(l)

        fh_out.flush()



if __name__ == '__main__':
  sys.exit(main(*sys.argv))
