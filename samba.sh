#!/usr/bin/env bash
#===============================================================================
#          FILE: samba.sh
#
#         USAGE: ./samba.sh
#
#   DESCRIPTION: Entrypoint for samba docker container with public access
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: David Personette (dperson@gmail.com),
#      MODIFIED: Eduard Kibort 05/04/2015
#  ORGANIZATION:
#       CREATED: 09/28/2014 12:11
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

### share: Add share
# Arguments:
#   share) share name
#   path) path to share
#   browseable) 'yes' or 'no'
#   readonly) 'yes' or 'no'
#   guest) 'yes' or 'no'
#   writable) 'yes' or 'no'
#   public) 'yes' or 'no'
#   users) list of allowed users
# Return: result
share() { local share="$1" path="$2" browse=${3:-yes} ro=${4:-yes}\
                guest=${5:-yes} rw=${6:-no} pub=${7:-yes} users=${8:-""} file=/etc/samba/smb.conf
    sed -i "/\\[$share\\]/,/^\$/d" $file
    echo "[$share]" >> $file
    echo "   path = $path" >> $file
    echo "   browseable = $browse" >> $file
    echo "   read only = $ro" >> $file
    echo "   writable = $rw" >> $file
    echo "   public = $pub" >> $file
    echo "   guest ok = $guest" >> $file
    [[ ${users:-""} ]] &&
        echo "   valid users = $(tr ',' ' ' <<< $users)" >> $file
    echo -e "" >> $file
}

### timezone: Set the timezone for the container
# Arguments:
#   timezone) for example EST5EDT
# Return: the correct zoneinfo file will be symlinked into place
timezone() { local timezone="${1:-EST5EDT}"
    [[ -e /usr/share/zoneinfo/$timezone ]] || {
        echo "ERROR: invalid timezone specified" >&2
        return
    }

    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
}

### user: add a user
# Arguments:
#   name) for user
#   password) for user
# Return: user added to container
user() { local name="${1}" passwd="${2}"
    useradd "$name" -M
    echo "$passwd" | tee - | smbpasswd -s -a "$name"
}
### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC=${1:-0}
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -s \"<name;/path>[;browse;readonly;guest;writable;public;users]\" Configure a share
                required arg: \"<name>;<comment>;</path>\"
                <name> is how it's called for clients
                <path> path to share
                [browseable] default:'yes' or 'no'
                [readonly] default:'yes' or 'no'
                [guest] allowed default:'yes' or 'no'
                [writable] default:'no' or 'yes'
                [public]  default:'yes' or 'no'
                [users] allowed default:'all' or list of allowed users
    -t \"\"       Configure timezone
                possible arg: \"[timezone]\" - zoneinfo timezone for container
    -u \"<username;password>\"       Add a user
                required arg: \"<username>;<passwd>\"
                <username> for user
                <password> for user

The 'command' (if provided and valid) will be run instead of samba
" >&2
    exit $RC
}

while getopts ":ht:u:s:" opt; do
    case "$opt" in
        h) usage ;;
        s) eval share $(sed 's/^\|$/"/g; s/;/" "/g' <<< $OPTARG) ;;
        u) eval user $(sed 's/;/ /g' <<< $OPTARG) ;;
        t) timezone "$OPTARG" ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${TIMEZONE:-""}" ]] && timezone "$TIMEZONE"

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
else
    exec ionice -c 3 smbd -FS
fi
