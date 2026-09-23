# bash serve.sh a 1234

extensions=('css' 'html' 'ico' 'js')
types=('text/css' 'text/html' 'image/x-icon' 'application/javascript')

prepare() {
    folder=$1
    line=($2)
    file="${line[1]//'%20'/' '}"
    if [[ "$file" != '/'* || $file = '/' ]]; then
        file='/x.html'
        type='text/html'
    else
        extension=${file##*.}
        for ((i=0, length=${#extensions[@]}; i < length; i++)); do
            if [[ "$extension" = "${extensions[$i]}" ]]; then
                type=${types[$i]}
            fi
        done
    fi
    echo "$folder$file"
    echo "$type"
}

preparea() {
    folder=$1
    read line
    readarray -t f < <(prepare "$folder" "$line")
    if [[ -e "${f[0]}" ]]; then
        echo -n $'HTTP/1.\ncontent-type:'"${f[1]}"$'\n\n'
        cat "${f[0]}"
    fi
}

prepareb() {
    folder=$1
    port=$2
    while read line; do
        if [[ $line = 'GET /'* ]]; then
            readarray -t f < <(prepare "$folder" "$line")
            if [[ -e "${f[0]}" ]]; then
                if [[ "${f[1]}" = 'text/html' ]]; then
                    : $(echo $'HTTP/1.\ncontent-type:'"${f[1]}"$'\n\n'"$(<"${f[0]}")" | netcat -l -w 0 $port)
                else
                    : $(echo $'HTTP/1.\ncontent-type:'"${f[1]}"$'\n\n' | netcat -l -w 0 $port < "${f[0]}")
                fi
            fi
        fi
    done
}

serve() {
    folder=${1:-a}
    port=${2:-1234}
    if test "$(type -t socat)"; then
        echo 'localhost:'$port
        : $(socat tcp-l:$port,fork,reuseaddr exec:"$SHELL ${BASH_SOURCE[0]} \'$folder\' $port a" 2>&1)
    elif test "$(type -t netcat)"; then
        echo 'localhost:'$port
        netcat -6 -k -l -w 1 $port | $SHELL ${BASH_SOURCE[0]} "$folder" $port b
    else
        echo 'no'
    fi
}

case $3 in
    (a) preparea "${@}" ;;
    (b) prepareb "${@}" ;;
    (*) serve "${@}" ;;
esac