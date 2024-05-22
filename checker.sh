#!/bin/sh

# Allowed command prefixes
ALLOWED_PREFIXES="python python3 pip"

# Function to check if the command starts with an allowed prefix
prefix_is_allowed() {
    local command="$1"
    for prefix in $ALLOWED_PREFIXES; do
        case "$command" in
            "$prefix"*) return 0 ;;
        esac
    done
    return 1
}

# Function to split the input command into individual commands based on '&&', '||', and ';'
split_commands() {
    echo "$1" | awk '
    {
        while (match($0, /&&|\|\||;/)) {
            cmd = substr($0, 1, RSTART - 1)
            gsub(/^[ \t]+|[ \t]+$/, "", cmd) # Trim leading and trailing whitespace
            print cmd
            $0 = substr($0, RSTART + RLENGTH)
        }
        gsub(/^[ \t]+|[ \t]+$/, "", $0) # Trim leading and trailing whitespace
        if (length($0) > 0) print $0
    }'
}

# Main execution block
input_command="$*"

# Handle case where command is passed with -c
if [ "$1" = "-c" ]; then
    input_command="$2"
fi

# Split the input command into individual commands using the split_commands function
commands=$(split_commands "$input_command")

# Initialize a flag to track if all commands are allowed
all_allowed=true

# Open file descriptor 3 and redirect the commands to it
exec 3<<EOF
$commands
EOF

# Read each command from file descriptor 3 and check if it has an allowed prefix
while IFS= read -r cmd <&3; do
    # Check if the command is allowed
    if ! prefix_is_allowed "$cmd"; then
        echo "Command not allowed: $cmd"
        all_allowed=false
        break
    fi
done

# Close file descriptor 3
exec 3<&-

# Execute the original command if all subcommands are allowed
if $all_allowed; then
    if [ "$1" = "-c" ]; then
        sh -c "$input_command"
    else
        sh -c "$input_command"
    fi
else
    exit 1
fi
