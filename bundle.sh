# bash bundle.sh a/a.js a/y.js

base64='$0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz'

resolve() {
    f=$1
    file=$2
    if [[ $f = './'* ]]; then
        f=${f:2}
    fi
    i=${f::1}
    if [[ $i != '.' && $i != '/' ]]; then
        f=${file%'/'*}'/'$f
    elif [[ $f = '../'* ]]; then
        while [[ $f = '../'* ]]; do
            f=${f:3}
            file=${file%'/'*}
        done
        f=${file%'/'*}'/'$f
    fi
    if [[ $f != *'.js' ]]; then
        f+='.js'
    fi
    echo "$f"
}

substitute() {
    text=$1
    past=$2
    next=$3
    a=0
    i=${#past}
    j=${#next}
    while [[ ${text:a} = *$past* ]]; do
        b=${text:a}
        b=${b%%$past*}
        a=$((a + ${#b}))
        if [[ ${#text} -lt $((a + i + 1)) ]]; then
            break
        elif [[ $base64 = *${text:a+i:1}* || ($a -ne 0 && $base64"\"'." = *${text:a-1:1}*) ]]; then
            a=$((a + i))
            continue
        fi
        text=${text::a}$next${text:a+i}
        a=$((a + j))
    done
    echo "$text"
}

parse() {
    file=$1
    if [[ -e "$file" ]]; then
        text=$(<"$file")
    else
        textsa+=("$file")
        textsb+=('')
        return
    fi
    IFS=$'\n' read -d '' -r -a lines <<< "$text"
    remove=false
    text=''
    for line in "${lines[@]}"; do
        if [[ ${line#"${line%%[![:blank:]]*}"} = '//'* ]]; then
            continue
        fi
        if [[ !$remove && $line = *'/*'* && $line != *'//*'* ]]; then
            i=${line%%'*/'*}
            i=${#i}
            if [[ $i -ne ${#line} ]]; then
                line=${line%%'/*'*}' '${line:i+2}
            else
                line=${line%%'/*'*}
                remove=true
            fi
        fi
        if $remove; then
            i=${line%%'*/'*}
            i=${#i}
            if [[ $i -ne ${#line} ]]; then
                line=${line:i+2}
                remove=false
            else
                continue
            fi
        fi
        line=${line%"${line##*[![:blank:]]}"}
        if [[ $line ]]; then
            text+=$line$'\n'
        fi
    done
    filesa=("$file")
    filesb=('')
    order=()
    texta=$text
    i=${text%%'import '*}
    i=${#i}
    while [[ $i -ne ${#text} ]]; do
        if [[ $i -ne 0 ]]; then
            j=${text:i-1:1}
            if [[ $j != $'\t' && $j != $'\n' && $j != ' ' ]]; then
                text=${text:i+6}
                i=${text%%'import '*}
                i=${#i}
                continue
            fi
        fi
        i=$((i + 6))
        while [[ ${text:i:1} = ' ' ]]; do
            i=$((i + 1))
        done
        text=${text:i}
        i=${text%%'from'*}
        i=${#i}
        j=${text%%'"'*}
        k=${text%%"'"*}
        names=()
        if [[ $i -lt ${#j} && $i -lt ${#k} ]]; then
            while [[ $i -lt ${#text} ]]; do
                j=${text:i-1:1}
                k=${text:i+4:1}
                if [[ ($j = ' ' || $j = '}') && ($k = ' ' || $k = '"' || $k = "'") ]]; then
                    break
                fi
                i=$((i + 4))
                j=${text:i}
                j=${j%%'from'*}
                i=$((i + ${#j}))
            done
            IFS=' ,{}' read -r -a names <<< "${text::i}"
            i=$((i + 5))
            while [[ ${text:i:1} = ' ' ]]; do
                i=$((i + 1))
            done
        else
            i=0
        fi
        f=${text:i:1}
        if [[ $f = '"' || $f = "'" ]]; then
            text=${text:i+1}
            f=$(resolve "${text%%$f*}" "$file")
            found=false
            for i in "${order[@]}"; do
                if [[ "$i" = "$f" ]]; then
                    found=true
                    break
                fi
            done
            if [[ $found = false ]]; then
                j=${#filesa[@]}
                filesa+=("$f")
                filesb+=('')
                order+=("$f")
            else
                for i in "${!filesa[@]}"; do
                    if [[ "${filesa[$i]}" = "$f" ]]; then
                        j=$i
                        break
                    fi
                done
            fi
            for name in "${names[@]}"; do
                filesb[$j]+=$name$'\n'
            done
        fi
        i=${text%%'import '*}
        i=${#i}
    done
    mods=''
    j=-1
    for i in "${!modulesa[@]}"; do
        if [[ "${modulesa[$i]}" = "$file" ]]; then
            j=$i
            modulesb[$j]=''
            break
        fi
    done
    if [[ $j = -1 ]]; then
        j=${#modulesa[@]}
        modulesa+=("$file")
        modulesb+=("$mods")
    fi
    for f in "${order[@]}"; do
        found=false
        for i in "${textsa[@]}"; do
            if [[ "$i" = "$f" ]]; then
                found=true
                break
            fi
        done
        if [[ $found = false ]]; then
            mods+=$f$'\n'
            found=false
            for i in "${modulesa[@]}"; do
                if [[ "$i" = "$f" ]]; then
                    found=true
                    break
                fi
            done
            if [[ $found = false ]]; then
                modulesa[$j]="$file"
                modulesb[$j]="$mods"
                return
            fi
        fi
    done
    declares=('async' 'class' 'const' 'default' 'function' 'let' 'var')
    defines=($'\n' ' ' '(' ',' '.' '[')
    text=$texta
    i=${text%%'export '*}
    i=${#i}
    while [[ $i -ne ${#text} ]]; do
        text=${text:i+7}
        for name in "${declares[@]}"; do
            i=${text%%$name*}
            i=${#i}
            if [[ $i -ne ${#text} && $i -lt 3 ]]; then
                text=${text:i+${#name}}
            fi
        done
        names=''
        i=${text%%$'\n'*}
        if [[ ${#i} -ne ${#text} ]]; then
            names=$i
        fi
        i=0
        while [[ ${names:i:1} = ' ' ]]; do
            i=$((i + 1))
        done
        split=()
        if [[ ${names:i:1} = '{' ]]; then
            names=${names:i+1}
            IFS=',' read -r -a split <<< "${names%%'}'*}"
        else
            i=${names%%'('*}
            i=${#i}
            j=${names%%'='*}
            k=${#j}
            if [[ $k -eq ${#names} || ($i -lt $k && $i -ne ${#names}) ]]; then
                split+=("$names")
            else
                while [[ $k -ne ${#names} && ${names:k+1:1} != '>' ]]; do
                    split+=("$j")
                    names=${names:k}
                    j=${names%%','*}
                    j=${#j}
                    if [[ $j -eq ${#names} ]]; then
                        break
                    fi
                    names=${names:j}
                    j=${names%%'='*}
                    k=${#j}
                done
            fi
        fi
        i=-1
        for j in "${!filesa[@]}"; do
            if [[ "${filesa[$j]}" = "$file" ]]; then
                i=$j
                break
            fi
        done
        for name in "${split[@]}"; do
            while [[ "${defines[@]}" =~ ${name::1} ]]; do
                name=${name:1}
            done
            for j in "${defines[@]}"; do
                k=${name%%$j*}
                if [[ ${#k} -ne ${#name} ]]; then
                    name=$k
                fi
            done
            filesb[$i]+=$name$'\n'
        done
        i=${text%%'export '*}
        i=${#i}
    done
    text=$texta
    for i in "${!filesa[@]}"; do
        f="${filesa[$i]}"
        path=${f::${#f}-3}
        path=$(echo -n $path | tr -c $base64 '_')
        IFS=$'\n' read -d '' -r -a names <<< "${filesb[$i]}"
        for name in "${names[@]}"; do
            text=$(substitute "$text" $name $name'_'$path)
        done
    done
    IFS=$'\n' read -d '' -r -a lines <<< "$text"
    text=''
    for line in "${lines[@]}"; do
        a=${line#"${line%%[![:blank:]]*}"}
        if [[ $a = 'export default '* ]]; then
            line=${a:15}
        elif [[ $a = 'export '* ]]; then
            line=${a:7}
            a=${line#"${line%%[![:blank:]]*}"}
            if [[ ${a::1} = '{' ]]; then
                continue
            fi
        fi
        if [[ $line && $a != 'import '* ]]; then
            text+=$line$'\n'
        fi
    done
    textsa+=("$file")
    textsb+=("$text")
}

build() {
    file=${1:-a/a.js}
    output=${2:-a/y.js}
    imported=()
    imports=("$file")
    modulesa=()
    modulesb=()
    textsa=()
    textsb=()
    while [[ ${#imports[@]} -ne 0 ]]; do
        file=${imports[0]}
        found=false
        for i in "${imported[@]}"; do
            if [[ "$i" = "$file" ]]; then
                found=true
                imports=("${imports[@]:1}")
                break
            fi
        done
        if [[ $found = false ]]; then
            parse "$file"
            for i in "${!modulesa[@]}"; do
                if [[ "${modulesa[$i]}" = "$file" ]]; then
                    IFS=$'\n' read -d '' -r -a mods <<< "${modulesb[$i]}"
                    break
                fi
            done
            imports=("${mods[@]}" "${imports[@]}")
            found=false
            for i in "${textsa[@]}"; do
                if [[ "$i" = "$file" ]]; then
                    imported+=("$file")
                    break
                fi
            done
        fi
    done
    text=''
    for file in "${imported[@]}"; do
        for i in "${!textsa[@]}"; do
            if [[ "${textsa[$i]}" = "$file" ]]; then
                text+="${textsb[$i]}"
                break
            fi
        done
    done
    echo -n "$text" > "$output"
}

build "$1" "$2"