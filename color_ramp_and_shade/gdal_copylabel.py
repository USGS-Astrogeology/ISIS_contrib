#!/bin/sh

TARGET=$0

FWTOOLS_HOME=/usgs/dev/contrib/bin/FWTools-linux-x86_64-3.0.6f-usgs

. $FWTOOLS_HOME/fwtools_env.sh

$FWTOOLS_HOME/usr/bin/`basename $TARGET` "$@"
