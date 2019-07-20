#!/bin/bash
#
# A collection of bash snippets and functions.
#

##########
# Arrays #
##########

#
# ### Array contains
#
# The only proper way to do this is by looping through each item. Other
# solutions claim to do this using string matching, but they are often
# dangerous because they don't handle edge cases, e.g. may be susceptible to
# partial match or may not properly handle elements containing newlines.
#

#
# Returns 0 if item is in the array; 1 otherwise.
#
# $1: name of the array variable to search
# $2: array item to search for
#
array_contains() {
    local arr_name=$1
    local item=$2

    eval "local -a _tmp_arr=(\"\${${arr_name}[@]}\")"

    for val in "${_tmp_arr[@]}"; do
        if [ "$val" == "$item" ]; then
            return 0
        fi
    done

    return 1
}


#
# Returns 0 if regexp matches any item in the array; 1 otherwise.
#
# $1: name of the array variable to search
# $2: regexp to match
#
array_contains_regexp() {
    local arr_name=$1
    local item=$2

    eval "local -a _tmp_arr=(\"\${${arr_name}[@]}\")"

    for val in "${_tmp_arr[@]}"; do
        if [[ "$val" =~ $item ]]; then
            return 0
        fi
    done

    return 1
}

# ### Array filter

#
# Remove elements from the named array. Iterate over each element and call
# named function. If the function returns false, the element is removed.
#
# $1: name of the array variable
# $@: name of the function to call plus any arguments; element to test will be
#     provided as the last arg
#
array_filter() {
    local arr_name=$1; shift
    local func_name=$1; shift
    local -a func_args=("$@")

    # Escape func args
    for i in "${!func_args[@]}"; do
        func_args[$i]=\'"${func_args[@]}"\'
    done

    eval "local -a _tmp_arr=(\"\${${arr_name}[@]}\")"

    local -a filtered_arr=()
    for val in "${_tmp_arr[@]}"; do
        if ! eval "$func_name" "${func_args[@]}" "$val"; then
            filtered_arr+=("$val")
        fi
    done

    eval "${arr_name}=(\"\${filtered_arr[@]}\")"
}

# ### Array join

#
# Join array elements with a string.
#
# $1: String separator
# $@: Array elements
#
array_join() {
    local sep=$1; shift
    IFS=$sep eval 'echo "$*"'
}

#
# $1: name of the array variable
# $2: index of element to remove
#
array_pop() {
    local arr_name=$1
    local -i index=$2

    eval "local -a _tmp_arr=(\"\${${arr_name}[@]}\")"

    if [ "$index" -gt $((${#_tmp_arr[@]} - 1)) ]; then
        echo "array_pop: index out of range" >&2
        return 1
    fi

    local -a filtered_arr=()
    local -i c=-1
    for val in "${_tmp_arr[@]}"; do
        c=$((c+1))
        # Skip item at index
        [ $c -eq $index ] && continue

        filtered_arr+=("$val")
    done

    eval "${arr_name}=(\"\${filtered_arr[@]}\")"
}

################
# Benchmarking #
################

# ### Time a command

#
# Time the number of seconds it takes to run a command; store the value in a
# variable with the specified name.
#
timer() {
    local var_name=$1; shift

    local end
    local -i ret=0
    local start
    local total

    start=$(date +%s)
    "$@" || ret=$?
    end=$(date +%s)

    total=$((end - start))

    # Store the value
    eval "${var_name}=${total}"

    return $ret
}

#################
# Path handling #
#################

#
# ### Resolve absolute path
#
# There are several snippets of code on the internet to resolve the absolute
# path, but most of them have issues. This function works on files, directories
# and handles "." and "..".
#

#
# Print the absolute path of the target path. Note that the path must be a
# real path to a file or directory or else this will fail.
#
# $1: the target file or directory
#
absolute_path() {
    local path=$1

    if [ "$path" == "." ]; then
        echo "$(pwd)"
    elif [ "$path" == ".." ]; then
        echo "$(dirname "$(pwd)")"
    else
        path="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
        # Replace double slashes, happens when we're operating at the root
        echo "${path/\/\///}"
    fi
}

#
# ### Recursively resolve symlinks
#
# This does what `realpath` from coreutils does but works without it. Requires
# readlink instead.
#

#
# Recursively resolve all symlinks at the specified path and then print the
# final, absolute path.
#
# $1: the path to resolve
#
resolve_symlinks() {
    (
        local path=$1

        while [ -L "$path" ]; do
            dir="$(dirname "$(absolute_path "$path")")"
            cd "$dir"
            path=$(readlink "$path")
        done

        echo "$(absolute_path "$path")"
    )
}

####################
# Process handling #
####################

# ### Clean up child processes on exit

#
# ```
# trap "exit" INT TERM
# trap "kill 0" EXIT
# ```
#

#
# Notes:
#
# * Doing the kill on exit means children will be cleaned up even during normal
#   exit too.
# * Binding INT/TERM to `exit` avoids an infinite loop in signal handling.
# * `kill 0` (with `0` as the PID) sends a TERM to the entire process group.
#

# ### Get PID of a subshell

#
# **Bash3:**
#
# ```
# (sh -c 'echo $PPID' && :)
# ```

#
# Notes:
#
# * Two statements are required to actually create the subshell
# * The second statement is essentially a "no-op"

#
# **Bash4:**
#
# ```
# echo $BASHPID
# ```

# ### Run commands in parallel

#
# This provides the ability to run commands in parallel with a predefined
# number of threads.
#
# People tend to use GNU `parallel` for this, however, implementing this as a
# shell function has the following advantages:
#
# * It is portable (doesn't require `parallel` to be installed).
# * You can run shell functions as commands, whereas external programs require
#   the commands to be standalone binaries.

#
# Run commands in parallel.
#
parallel() {
    local max_threads=$1
    local -a pids=()
    local ret=0

    # Set up named pipe to communicate between procs
    fifo="$(mktemp)" && rm -f "$fifo"
    mkfifo -m 0700 "$fifo"

    # Open pipe as fd 3
    exec 3<>$fifo
    rm -f $fifo # Clean up pipe from filesystem; it stays open, however

    local running=0
    while read cmd; do
        # Block, when at max_threads
        while ((running >= max_threads)); do
            if read -u 3 cpid ; then
                wait $cpid || true
                ((--running))
            fi
        done

        # Spawn child proc
        ($cmd; sh -c 'echo $PPID 1>&3' && :) &
        pids+=($!)

        ((++running))
    done

    # Return 1 if one or more pids returned a nonzero code
    for pid in "${pids[@]}"; do
        wait "$pid" || ret=1
    done

    return $ret
}

#
# Notes:
#
# * Provide the commands as an input to this function
#

# ### Wait for background processes to exit

#
# ```
# wait [PID [...]]
# ```
#
# Notes:
#
# * If you use `wait` without specifying a PID, bash will wait for *all*
#   background processes.
# * If you want to catch the return code of the background process, you
#   **must** specify the PID.
# * If you specify multiple PIDs, the return code of `wait` will be the return
#   code of the *last* PID specified.
#

###########
# Testing #
###########

#
# $1: string to match
# $2: value to check
#
match_string() {
    [ "$2" == "$1" ]
}

#
# $1: regexp
# $2: value to check
#
match_regexp() {
    [[ "$2" =~ $1 ]]
}

# ### List all test functions

#
# Outputs the name of all functions starting with `test_`.
#
# ```
# $(compgen -A function | grep -E ^test_)
# ```

# ### Run test functions

#
# Runs the specified test functions and outputs the result. If a test fails,
# it outputs a trace of the test to stderr.
#

#
# Run specified tests.
#
tests() {
    local ret=0
    local test_log="/tmp/${0##*/}.test.log"

    for test in "$@"; do
        :>"$test_log"

        echo -n "$test: "
        if (set -x; $test) 2>"$test_log"; then
            echo "OK"
        else
            echo "FAILED"
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

########
# Time #
########

# ### Human-readable time output

#
# Given seconds, outputs something like "2m 5s".
#

#
# Output human readable duration, given seconds as an input.
#
prettify_time() {
    local time_secs=$1

    local mins
    local secs

    mins=$(($time_secs / 60))
    secs=$(($time_secs % 60))

    if [ $mins -gt 0 ]; then
        echo -n "${mins}m "
    fi

    echo "${secs}s"
}

#############
# Utilities #
#############

# ### Check a required program is installed

#
# $@: list of programs to check for
#
require() {
    local ret=0

    for bin in "$@"; do
        if ! which "$bin" &>/dev/null; then
            echo "ERROR: Missing required dependency: ${bin}" >&2
            ret=1
        fi
    done

    return $ret
}
