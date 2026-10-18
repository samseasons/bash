# bash bundle.sh a/a.js a/y.js

base64='$0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz'

resolve() {
    f=$1
    file=$2
    while [[ $f = '../'* ]]; do
        f=${f:3}
        file=${file%'/'*}
    done
    f=${file%'/'*}'/'$f
    treats=('' '/' '' '' '/' '\' '')
    tricks=('~' ':' './' '.\' '//' '\\' '../')
    for i in "${!treats[@]}"; do
        treat=${treats[$i]}
        trick=${tricks[$i]}
        while [[ $f = *$trick* ]]; do
            f="${f/$trick/$treat}"
        done
    done
    while [[ $f = '/'* || $f = '\'* ]]; do
        f=${f:1}
    done
    if [[ $f != *'.js' ]]; then
        f+='.js'
    fi
    echo "$f"
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
    remove=0
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
                remove=1
            fi
        fi
        if [[ $remove -ne 0 ]]; then
            i=${line%%'*/'*}
            i=${#i}
            if [[ $i -ne ${#line} ]]; then
                line=${line:i+2}
                remove=0
            else
                continue
            fi
        fi
        line=${line%"${line##*[![:blank:]]}"}
        if [[ $line ]]; then
            text+=$line$'\n'
        fi
    done
    defaultsa=()
    defaultsb=()
    exportsa=("$file")
    exportsb=('')
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
        defaulted=''
        namesa=()
        namesb=()
        text=${text:i}
        i=${text%%'from'*}
        i=${#i}
        j=${text%%'"'*}
        k=${text%%"'"*}
        if [[ $i -lt ${#j} && $i -lt ${#k} ]]; then
            length=${#text}
            while [[ $i -lt $length ]]; do
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
            variables=${text::i}
            j=${text%%'{'*}
            j=${#j}
            if [[ $j -ne ${#text} ]]; then
                k=${text%%'}'*}
                k=${#k}
                IFS=',' read -r -a split <<< "${variables:j+1:k-j-1}"
                variables=${variables::j}
                for name in "${split[@]}"; do
                    name=${name#"${name%%[![:blank:]]*}"}
                    name=${name%"${name##*[![:blank:]]}"}
                    j=${name%%' as '*}
                    j=${#j}
                    if [[ $j -ne ${#name} ]]; then
                        namesa+=(${name::j})
                        namesb+=(${name:j+4})
                    elif [[ $name ]]; then
                        namesa+=($name)
                        namesb+=($name)
                    fi
                done
            fi
            name=${variables%%','*}
            name=${name#"${name%%[![:blank:]]*}"}
            name=${name%"${name##*[![:blank:]]}"}
            if [[ $name ]]; then
                defaulted=$name
                namesa+=($name)
                namesb+=($name)
            fi
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
            found=0
            for i in "${order[@]}"; do
                if [[ "$i" = "$f" ]]; then
                    found=1
                    break
                fi
            done
            if [[ $found -eq 0 ]]; then
                j=${#exportsa[@]}
                exportsa+=("$f")
                exportsb+=('')
                order+=("$f")
            else
                for i in "${!exportsa[@]}"; do
                    if [[ "${exportsa[$i]}" = "$f" ]]; then
                        j=$i
                        break
                    fi
                done
            fi
            if [[ $defaulted ]]; then
                defaultsa+=("$f")
                defaultsb+=($defaulted)
            fi
            for i in "${!namesa[@]}"; do
                exportsb[$j]+=${namesa[$i]}' '${namesb[$i]}$'\n'
            done
        fi
        i=${text%%'import '*}
        i=${#i}
    done
    dependencies=0
    mods=''
    for f in "${order[@]}"; do
        found=0
        for i in "${textsa[@]}"; do
            if [[ "$i" = "$f" ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            mods+=$f$'\n'
            found=0
            for i in "${modulesa[@]}"; do
                if [[ "$i" = "$f" ]]; then
                    found=1
                    break
                fi
            done
            if [[ $found -eq 0 ]]; then
                j=-1
                for i in "${!modulesa[@]}"; do
                    if [[ "${modulesa[$i]}" = "$file" ]]; then
                        j=$i
                        break
                    fi
                done
                if [[ $j -eq -1 ]]; then
                    j=${#modulesa[@]}
                fi
                dependencies=1
            fi
        fi
    done
    if [[ $dependencies = 1 ]]; then
        modulesa[$j]="$file"
        modulesb[$j]="$mods"
        return
    fi
    declares=('async' 'class' 'const' 'default' 'function' 'let' 'var')
    defines=($'\n' ' ' '(' ',' '.' '[')
    text=$texta
    i=${text%%'export '*}
    i=${#i}
    while [[ $i -ne ${#text} ]]; do
        text=${text:i+7}
        i=${text%%'default '*}
        if [[ ${#i} -eq 0 ]]; then
            i=${text%%'export '*}
            i=${#i}
            continue
        fi
        for name in "${declares[@]}"; do
            i=${text%%$name*}
            i=${#i}
            if [[ $i -ne ${#text} && $i -lt 3 ]]; then
                text=${text:i+${#name}}
            fi
        done
        i=${text%%$'\n'*}
        if [[ ${#i} -ne ${#text} ]]; then
            variables=$i
            i=0
            length=${#name}
            while [[ $i -lt $length && ${variables:i:1} = ' ' ]]; do
                i=$((i + 1))
            done
            split=()
            if [[ $i -lt $length && ${variables:i:1} = '{' ]]; then
                variables=${variables:i+1}
                IFS=',' read -r -a split <<< "${variables%%'}'*}"
            else
                i=${variables%%'('*}
                i=${#i}
                j=${variables%%'='*}
                k=${#j}
                if [[ $k -eq ${#variables} || ($i -lt $k && $i -ne ${#variables}) ]]; then
                    split+=("$variables")
                else
                    while [[ $k -ne ${#variables} && ${variables:k+1:1} != '>' ]]; do
                        split+=("$j")
                        variables=${variables:k}
                        j=${variables%%','*}
                        j=${#j}
                        if [[ $j -eq ${#variables} ]]; then
                            break
                        fi
                        variables=${variables:j}
                        j=${variables%%'='*}
                        k=${#j}
                    done
                fi
            fi
            i=-1
            for j in "${!exportsa[@]}"; do
                if [[ "${exportsa[$j]}" = "$file" ]]; then
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
                exportsb[$i]+=$name' '$name$'\n'
            done
        fi
        i=${text%%'export '*}
        i=${#i}
    done
    defaulted=''
    text=$texta
    for i in "${!exportsa[@]}"; do
        f="${exportsa[$i]}"
        path=${f::${#f}-3}
        path=$(echo -n $path | tr -c $base64 '_')
        if [[ "$f" = "$file" ]]; then
            defaulted=$path
        fi
        IFS=$'\n' read -d '' -r -a names <<< "${exportsb[$i]}"
        for name in "${names[@]}"; do
            i=${name%%' '*}
            i=${#i}
            named=${name::i}
            name=${name:i+1}
            found=0
            for i in "${!defaultsa[@]}"; do
                if [[ "${defaultsa[$i]}" = "$f" && ${defaultsb[$i]} = $name ]]; then
                    found=1
                    break
                fi
            done
            next='_'$path
            if [[ $found -eq 0 ]]; then
                next=$named$next
            fi
            i=${text%%$name*}
            i=${#i}
            j=${#name}
            k=${#next}
            while [[ $i -ne ${#text} ]]; do
                if [[ $base64 = *${text:i+j:1}* || ($i -ne 0 && $base64"\"'." = *${text:i-1:1}*) ]]; then
                    i=$((i + j))
                else
                    text=${text::i}$next${text:i+j}
                    i=$((i + k))
                fi
                b=${text:i}
                b=${b%%$name*}
                i=$((i + ${#b}))
            done
        done
    done
    IFS=$'\n' read -d '' -r -a lines <<< "$text"
    text=''
    for line in "${lines[@]}"; do
        a=${line#"${line%%[![:blank:]]*}"}
        if [[ $a = 'export default '* ]]; then
            line='_'$defaulted' = '${a:15}
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
        found=0
        for i in "${imported[@]}"; do
            if [[ "$i" = "$file" ]]; then
                found=1
                imports=("${imports[@]:1}")
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            parse "$file"
            for i in "${!modulesa[@]}"; do
                if [[ "${modulesa[$i]}" = "$file" ]]; then
                    IFS=$'\n' read -d '' -r -a mods <<< "${modulesb[$i]}"
                    imports=("${mods[@]}" "${imports[@]}")
                    break
                fi
            done
            for i in "${textsa[@]}"; do
                if [[ "$i" = "$file" ]]; then
                    imported+=("$file")
                    imports=("${imports[@]:1}")
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
    if [[ ${#text} -ne 0 ]]; then
        text=${text::${#text}-1}
    fi
    if [[ $output = *'.html' ]]; then
        text='<!doctype html><html><body><script>'"$text"'</script></body></html>'
        if [[ -e "$output" ]]; then
            t=$(<"$output")
            i=${t%%'<script'*}
            i=${#i}
            j=${t%%'</script'*}
            j=${#j}
            k=${#t}
            if [[ $i -eq $k || $j -eq $k ]]; then
                i=${t%%'</body'*}
                i=${#i}
                if [[ $i -ne $k ]]; then
                    text=${t::i}${text:27:${#text}-41}${t:i}
                fi
            else
                text=${t::i}${text:27:${#text}-41}${t:j+9}
            fi
        fi
    fi
    echo -n "$text" > "$output"
}

build "$1" "$2"