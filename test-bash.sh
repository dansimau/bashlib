#!/bin/bash

. "${0%/*}/bash.sh"

test_absolute_path_simple_root() {
    cd /
    [ "$(absolute_path "tmp")" == "/tmp" ] || return 1
}

test_absolute_path_multiple_levels() {
    touch /tmp/foo
    cd /

    [ "$(absolute_path "tmp/foo")" == "/tmp/foo" ] || return 1
}

test_absolute_path_double_dot() {
    mkdir -p /tmp/bar
    cd /tmp/bar

    [ "$(absolute_path "..")" == "/tmp" ] || return 1
}

test_absolute_path_single_dot() {
    mkdir -p /tmp/bar
    cd /tmp/bar

    [ "$(absolute_path ".")" == "/tmp/bar" ] || return 1
}

test_resolve_symlinks() {
    touch /tmp/foo
    mkdir -p /tmp/1/2
    ln -sf ../../foo /tmp/1/2/foo

    [ "$(resolve_symlinks /tmp/1/2/foo)" == "/tmp/foo" ] || return 1
}

test_prettify_time() {
    [ "$(prettify_time 0)" == "0s" ] || return 1
    [ "$(prettify_time 61)" == "1m 1s" ] || return 1
    [ "$(prettify_time 7200)" == "2h" ] || return 1
    [ "$(prettify_time 7259)" == "2h 59s" ] || return 1
    [ "$(prettify_time 7259)" == "2h 59s" ] || return 1
    [ "$(prettify_time 10740)" == "2h 59m" ] || return 1
    [ "$(prettify_time 10799)" == "2h 59m 59s" ] || return 1
    [ "$(prettify_time 86400)" == "24h" ] || return 1
}

tests() {
    local ret=0
    local test_log="/tmp/${0##*/}.test.log"

    for test in "$@"; do
        :>"$test_log"

        echo -n "$test: "
        if (set -x; $test) 2>"$test_log"; then
            echo -e "\033[32mOK\033[0m"
        else
            echo -e "\033[31mFAILED\033[0m"
            ret=1

            {
                echo
                echo "Trace:"

                echo -e "\033[33m"
                cat "$test_log"
                echo -e "\033[0m"
            } >&2
        fi
    done

    return $ret
}

main() {
    echo "Testing bash version: ${BASH_VERSION}"
    tests "$@"
}

if [ "$0" == "$BASH_SOURCE" ]; then
    main $(compgen -A function | grep -E ^test_)
fi
