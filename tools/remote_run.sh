#!/bin/sh
set -eu

remote_host=${REMOTE_HOST:-mac-studio.local}
remote_dir=${REMOTE_DIR:-/tmp/tang-primer-20k-z80-remote}
action=${1:-build}

case "$action" in
    build|sim|sim-uvc) ;;
    *)
        echo "usage: $0 {build|sim|sim-uvc}" >&2
        exit 2
        ;;
esac

echo "Remote host: $remote_host"
echo "Remote directory: $remote_dir"

ssh -o BatchMode=yes "$remote_host" "mkdir -p '$remote_dir'"
rsync -a --delete \
    --exclude=.git \
    --exclude=impl/gwsynthesis \
    --exclude=impl/pnr \
    --exclude=sim/top_sim \
    --exclude=sim/uvc_sim \
    ./ "$remote_host:$remote_dir/"

ssh -o BatchMode=yes "$remote_host" \
    "cd '$remote_dir' && PATH=/opt/homebrew/bin:\$PATH /usr/bin/time -p make '$action'"

if [ "$action" = build ] || [ "$action" = sim ]; then
    mkdir -p firmware/generated
    rsync -a \
        "$remote_host:$remote_dir/firmware/generated/boot.hex" \
        "$remote_host:$remote_dir/firmware/generated/psg_demo.hex" \
        firmware/generated/
    echo "Fetched assembled firmware HEX files"
fi

if [ "$action" = build ]; then
    mkdir -p impl/pnr
    rsync -a \
        "$remote_host:$remote_dir/impl/pnr/project.fs" \
        "$remote_host:$remote_dir/impl/pnr/project.rpt.txt" \
        impl/pnr/
    echo "Fetched impl/pnr/project.fs and project.rpt.txt"
fi
