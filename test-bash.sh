#!/bin/bash

. "${0%/*}/bash.sh"

test_absolute_path_simple_root() {
    (
        cd /
        [ "$(absolute_path "tmp")" == "/tmp" ]
    )
}

test_absolute_path_multiple_levels() {
    (
        touch /tmp/foo
        cd /

        [ "$(absolute_path "tmp/foo")" == "/tmp/foo" ]
    )
}

test_absolute_path_double_dot() {
    (
        mkdir -p /tmp/bar
        cd /tmp/bar

        [ "$(absolute_path "..")" == "/tmp" ]
    )
}

test_absolute_path_single_dot() {
    (
        mkdir -p /tmp/bar
        cd /tmp/bar

        [ "$(absolute_path ".")" == "/tmp/bar" ]
    )
}

test_array_contains() {
    local -a test_input=("foo" "bar")
    array_contains test_input foo
}

test_array_contains_multiline() {
    local -a test_input=("foo" "bar"$'\n'"baz")
    array_contains test_input "bar"$'\n'"baz"
    ! array_contains test_input baz
}

test_array_contains_false() {
    local -a test_input=("foo" "bar")
    ! array_contains test_input baz
}

test_array_contains_does_not_do_partial_match() {
    local -a test_input=("foobar" "baz")
    ! array_contains test_input foo
}

test_array_contains_handles_whitespace_and_empty() {
    # We want to make sure our implementation doesn't collapse whitespaces, or
    # consider them to be the same, or consider "" to be equivalent.
    local -a test_input=(" " $'\n' "  ")
    ! array_contains test_input ""
}

test_array_contains_regexp() {
    local -a test_input=("foobar" "baz")
    array_contains_regexp test_input foo
}

test_array_filter() {
    local -a arr=("foo" "bar" "baz")

    array_filter arr match_string bar

    [ ${#arr[@]} -eq 2 ]
    [ "${arr[0]}" == "foo" ]
    [ "${arr[1]}" == "baz" ]
}

test_array_filter_multiline() {
    local -a arr=("foo" "bar"$'\n'"baz" "quux")
    [ ${#arr[@]} -eq 4 ]

    array_filter arr match_string "foo"

    [ ${#arr[@]} -eq 2 ]
    [ "${arr[0]}" == "bar"$'\n'"baz" ]
    [ "${arr[1]}" == "quux" ]
}

test_array_filter_regexp() {
    local -a arr=("foo" "bar" "baz")

    array_filter arr match_regexp "foo|bar"

    [ ${#arr[@]} -eq 1 ]
    [ "${arr[0]}" == "baz" ]
}

test_array_pop() {
    local -a arr=("foo" "bar"$'\n'"baz" "qux")
    [ ${#arr} -eq 3 ]

    array_pop arr 1

    [ ${#arr} -eq 2 ]
    [ "${arr[0]}" == "foo" ]
    [ "${arr[1]}" == "qux" ]
}

test_array_pop_out_of_range() {
    local -a arr=("foo" "bar")
    ! array_pop arr 2
}

test_resolve_symlinks() {
    touch /tmp/foo
    mkdir -p /tmp/1/2
    ln -sf ../../foo /tmp/1/2/foo

    [ "$(resolve_symlinks /tmp/1/2/foo)" == "/tmp/foo" ]
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
    local -a tests_to_run=("$@")

    if [ ${#tests_to_run[@]} -eq 0 ]; then
        tests_to_run=($(compgen -A function | grep -E ^test_))
    fi

    echo "Testing bash version: ${BASH_VERSION}"
    tests "${tests_to_run[@]}"
}

if [ "$0" == "$BASH_SOURCE" ]; then
    main "$@"
fi
