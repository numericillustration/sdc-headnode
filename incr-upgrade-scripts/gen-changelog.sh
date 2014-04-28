#!/bin/bash
#
# Generate a changelog from a given DC version summary to a 'upgrade-images'
# file. The former can be generated by `sdc-versions.sh -j`
# (https://mo.joyent.com/trentops/blob/master/bin/sdc-versions.sh) and the
# latter by `gen-upgrade-images.sh` in this repo.
#
# Usage:
#       ./gen-changelog.sh <sdc-versions-dump> <upgrade-images>
#


if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail


#---- globals

TOP=$(cd $(dirname $0)/; pwd)

# A start at this in the MG repo:
#   json -f targets.json -e 'var s=this; Object.keys(s).forEach(function (k) { if (s[k].repos) s[k] = s[k].repos[0].url });'
repo_url_from_service=$(cat <<EOM
{
  "smartlogin": "git@git.joyent.com:smart-login.git",
  "incr-upgrade": "git@git.joyent.com:usb-headnode.git",
  "ca": "git@git.joyent.com:cloud-analytics.git",
  "amon": "git@git.joyent.com:amon.git",
  "assets": "git@git.joyent.com:assets.git",
  "adminui": "git@git.joyent.com:adminui.git",
  "dhcpd": "git@git.joyent.com:booter.git",
  "redis": "git@git.joyent.com:redis.git",
  "amonredis": "git@git.joyent.com:amonredis.git",
  "rabbitmq": "git@git.joyent.com:rabbitmq.git",
  "cloudapi": "git@git.joyent.com:cloudapi.git",
  "usageapi": "git@git.joyent.com:usageapi.git",
  "ufds": "git@git.joyent.com:ufds.git",
  "workflow": "git@git.joyent.com:workflow.git",
  "vmapi": "git@git.joyent.com:vmapi.git",
  "papi": "git@git.joyent.com:papi.git",
  "imgapi": "git@git.joyent.com:imgapi.git",
  "sdc": "git@git.joyent.com:sdc.git",
  "imgapi-cli": "git@git.joyent.com:imgapi-cli.git",
  "heartbeater": "git@git.joyent.com:heartbeater.git",
  "provisioner": "git@git.joyent.com:provisioner.git",
  "zonetracker": "git@git.joyent.com:zonetracker.git",
  "hagfish-watcher": "git@git.joyent.com:hagfish-watcher.git",
  "firewaller": "git@git.joyent.com:firewaller.git",
  "cnapi": "git@git.joyent.com:cnapi.git",
  "fwapi": "git@git.joyent.com:fwapi.git",
  "napi": "git@git.joyent.com:napi.git",
  "sapi": "git@git.joyent.com:sapi.git",
  "binder": "git@git.joyent.com:binder.git",
  "manatee": "git@git.joyent.com:manatee.git",
  "moray": "git@git.joyent.com:moray.git",
  "sdcsso": "git@github.com:joyent/sdcsso.git",
  "manta-deployment": "git@git.joyent.com:manta-deployment.git"
}
EOM)


#---- support routines

function fatal
{
    echo "$0: fatal error: $*" >&2
    exit 1
}



#---- mainline

src=$1
dst=$2
[[ -f "$src" ]] || fatal "<sdc-versions-dump> is not an existing file: $src"
[[ -f "$dst" ]] || fatal "<upgrade-images> is not an existing file: $dst"

echo "# SDC upgrade changelog"
echo ""
echo '```'
cat $dst
echo '```'
echo ""
echo ""

echo "# incr-upgrade"
echo ""
echo "TODO"
echo ""
echo ""

echo "# agents"
echo ""
echo "TODO"
echo ""
echo ""


cat $dst | grep 'export ' | while read line; do
    service=$(echo "$line" | sed -E 's/^.* ([A-Z0-9]+)_IMAGE=.*$/\1/' \
        | tr 'A-Z' 'a-z')
    to_sha=$(echo "$line" | sed -E 's/^.* version=.*-g([0-9a-f]{7}) .*$/\1/')
    if [[ ${#to_sha} != 7 ]]; then
        # We couldn't parse "version=..." out of the line. Let's hit
        # updates.jo for that info.
        to_uuid=$(echo "$line" | cut -d'=' -f2 | cut -d' ' -f1)
        to_version=$(updates-imgadm get $to_uuid | json version)
        to_sha=$(echo $to_version | sed -E 's/^.*-g([0-9a-f]{7})$/\1/')
    fi
    [[ ${#to_sha} == 7 ]] || fatal "could not determine git sha for image: '$line'"
    from_sha=$(json -f $src -ga -c "this.service === '$service'" git)
    repo_url=$(echo "$repo_url_from_service" | json $service)
    echo "# $service ($repo_url $from_sha..$to_sha)"
    echo ""
    repo_dir=$TOP/tmp/$service
    if [[ -d $repo_dir ]]; then
        echo "Git pull $repo_url" >&2
        (cd $repo_dir && git pull >/dev/null)
    else
        echo "Git clone $repo_url" >&2
        mkdir -p $(dirname $repo_dir)
        rm -rf $repo_dir.tmp
        git clone $repo_url $repo_dir.tmp >/dev/null
        mv $repo_dir.tmp $repo_dir
    fi
    echo '```'
    # Compact git log, drop the timezone info for brevity.
    (cd $repo_dir && \
        git log --pretty=format:'[%ci] %h -%d %s <%an>' $from_sha..$to_sha \
        | sed -E 's/ [-+][0-9]{4}\]/]/')
    echo ""
    echo '```'
    # TODO: get full log, extract list of tickets and show ticket info
    echo ""
    echo ""
done

