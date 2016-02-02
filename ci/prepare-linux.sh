#!/bin/bash

sudo setcap cap_net_raw+ep fping
sudo setcap cap_net_raw+ep fping6

if [[ ! $PATH =~ fping/src ]]; then
    echo "# WARNING: must set PATH:"
    echo PATH=/home/dws/checkouts/fping/src:\$PATH
fi
