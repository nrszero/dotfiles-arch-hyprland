#!/bin/bash
DIR=$(cd "$(dirname "$0")" && pwd)
exec "$DIR/wallpaper-ctl.sh" daemon "$@"
