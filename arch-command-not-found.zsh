# Command Not Found Handler
function command_not_found_handler() {
    local cmd="$1"
    local prt="zsh: command not found: $cmd"

    local available_commands=()
    for c in $(compgen -c); do
        [[ "${c}" == _* ]] || available_commands+=("$c")
    done

    local closest_cmd=$(printf '%s\n' "${available_commands[@]}" | awk -v input="$cmd" '
    function levenshtein(s1, s2) {
        n = length(s1)
        m = length(s2)
        if (n == 0) return m
        if (m == 0) return n
        for (i = 0; i <= n; i++) d[i, 0] = i
        for (j = 0; j <= m; j++) d[0, j] = j
        for (i = 1; i <= n; i++) {
            for (j = 1; j <= m; j++) {
                cost = (substr(s1, i, 1) == substr(s2, j, 1)) ? 0 : 1
                d[i, j] = min(d[i-1, j] + 1, d[i, j-1] + 1, d[i-1, j-1] + cost)
            }
        }
        return d[n, m]
    }
    function min(a, b, c) {
        if (a <= b && a <= c) return a
        if (b <= a && b <= c) return b
        return c
    }
    BEGIN {
        closest = ""
        min_distance = 9999
    }
    {
        distance = levenshtein(input, $0)
        if (distance < min_distance) {
            min_distance = distance
            closest = $0
        }
    }
    END {
        print closest
    }')

    local green_bold_underline="\e[32;1;4m"
    local red_bold="\e[31;1m"
    local white="\e[37m"
    local reset="\e[0m"

    if command -v pacman &>/dev/null; then
        local spin_chars=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
        local i=0
        local pkg=""
        local tmpfile=$(mktemp)
        (pacman -Ss "^$cmd$" | awk -F '/' '{print $2}' | cut -d' ' -f1 | head -n 1 > "$tmpfile") &
        local pid=$!
        tput civis
        while kill -0 $pid 2>/dev/null; do
            printf "\r${white}${spin_chars[i]}${reset}"
            i=$(( (i+1) % 10 ))
            sleep 0.1
        done
        wait $pid
        pkg=$(<"$tmpfile")
        rm -f "$tmpfile"
        printf "\r%*s\r" "$(tput cols)" ""
        tput cnorm
    
        if [[ -n "$pkg" ]]; then
            echo -ne "${white}Do you want to install '$pkg'? [${green_bold_underline}Y${reset}${white}/${red_bold}n${reset}${white}] ${reset}"
            read install_choice
            install_choice="${install_choice:l}"
            if [[ -z "$install_choice" || "$install_choice" == "y" || "$install_choice" == "yes" ]]; then
                sudo pacman -Sy "$pkg" --noconfirm &>/dev/null
                case $? in
                    0)
                        print -n "\033[F\033[2K\r"
                        "$pkg" "${@:2}"
                        return $?
                        ;;
                    1)
                        print -n "\033[F\033[2K\r"
                        echo "Please install it manually."
                        return 1
                        ;;
                esac
            fi
        fi
    fi

    if [[ -n "$closest_cmd" ]]; then
        echo -ne "${white}Did you mean '${closest_cmd}'? [${green_bold_underline}Y${reset}${white}/${red_bold}n${reset}${white}] ${reset}"
        read choice
        print -n "\033[F\033[2K\r"
        choice="${choice:l}"
        if [[ -z "$choice" || "$choice" == "y" || "$choice" == "yes" ]]; then
            "$closest_cmd" "${@:2}"
            return $?
        fi
    fi

    return 127
}
