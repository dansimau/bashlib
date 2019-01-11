#!/bin/bash
#
# Generate markdown documentation from bash.sh.
#

#
# Write a function block to stdout.
#
output_func_block() {
    echo
    echo -n '```bash'
    echo "$@"
    echo '```'
}

#
# Write a markdown block to stdout.
#
output_markdown_block() {
    echo

    IFS=$'\n'
    for line in $@; do
        case "$line" in
            "#")
                echo
                ;;
            "#"*)
                echo "${line#\# }"
                ;;
            *)
                echo "ERROR: Unexpected data: $line" >&2
                exit 1
                ;;
        esac
    done
}

#
# Write a header to stdout.
#
output_markdown_header() {
    echo

    IFS=$'\n'
    for line in $@; do
        if [[ "$line" =~ ^\#+$ ]]; then
            continue
        else
            text="$line"
            text="${text#\# }"
            text="${text% \#}"
            echo "## $text"
            return
        fi
    done
}

main() {
    local -i body_started=0
    local -i block_open=0
    local -i func_open=0
    local buf=
    local prevline=

    _add_to_buffer() {
        buf="$buf"$'\n'"$@"
    }

    _reset_buffer() {
        buf=
    }

    _reset_all() {
        buf=
        prevline=
    }

    _process_end_of_block() {
        # Process/output previous block
        if [ "$prevline" == "}" ]; then
            output_func_block "$buf"
        elif [[ "$prevline" =~ ^\#\#\#+ ]]; then
            output_markdown_header "$buf"
        else
            output_markdown_block "$buf"
        fi
    }

    while read -r line; do
        case "$line" in
            # Func def start
            *"() {")
                func_open=1
                _add_to_buffer "$line"
                ;;

            # Func def end
            "}")
                func_open=0
                _add_to_buffer "$line"
                ;;

            # End of block
            "")
                # Only start processing from the first header encountered
                if [[ "$prevline" =~ ^\#\#\#+ ]]; then
                    body_started=1
                fi

                if [ $body_started -eq 0 ]; then
                    _reset_all
                    continue
                fi

                # Continue if we're inside a func dec
                if [ $func_open -eq 1 ]; then
                    _add_to_buffer "$line"
                    continue
                fi

                _process_end_of_block

                # Clear buffer, ready for new block
                _reset_buffer
                ;;

            # Add line to buffer
            *)
                _add_to_buffer "$line"
                ;;
        esac

        prevline="$line"
    done

    # End of file, process the remaining contents of the buffer
    _process_end_of_block
}

main "$@" <bash.sh
