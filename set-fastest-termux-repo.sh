#!/bin/bash

speed_test_mirror() {
    url=$1
    size=$(curl -sI "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')

    if [[ -z "$size" || "$size" == "Error:" ]]; then
        echo "Error: Unable to retrieve size for $url"
        echo "0 0"
        return
    fi

    size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)

    total_time=0
    attempts=3

    for i in $(seq 1 $attempts); do
        time=$(curl -o /dev/null -s -w '%{time_total}' "$url")

        if ! echo "$total_time + $time" | bc > /dev/null 2>&1; then
            echo "Error: bc failed with data: total_time=$total_time, time=$time"
            echo "0 0"
            return
        fi

        total_time=$(echo "$total_time + $time" | bc)
    done

    avg_time=$(echo "scale=3; $total_time / $attempts" | bc -l)

    if [[ $? -ne 0 ]]; then
        echo "Error: bc failed with data: total_time=$total_time, attempts=$attempts"
        echo "0 0"
        return
    fi

    echo "$size_mb $avg_time"
}

update_sources_list() {
    fastest_mirror=$1
    sources_list="$PREFIX/etc/apt/sources.list"

    # Backup the original sources.list
    cp "$sources_list" "$sources_list.bak"

    # Define the appropriate URL to update in sources.list
    case $fastest_mirror in
        "gnlug.org")
            mirror_url="https://gnlug.org/pub/termux/termux-main"
            ;;
        "mirror.mwt.me")
            mirror_url="https://mirror.mwt.me/termux/main"
            ;;
        *)
            mirror_url="https://$fastest_mirror"
            ;;
    esac

    # Update the URL in sources.list
    sed -i "s|https://[^ ]*|$mirror_url|" "$sources_list"
}

find_valid_url() {
    mirror=$1
    paths=(
        "/termux/termux-main/dists/stable/Contents-$(uname -m).gz"
        "/termux/main/dists/stable/Contents-$(uname -m).gz"
        "/pub/termux/termux-main/dists/stable/Contents-$(uname -m).gz"
        "/dists/stable/Contents-$(uname -m).gz"
        "/termux/termux-main/dists/stable/main/binary-$(uname -m)/Contents-$(uname -m).gz"
        "/pub/termux/termux-main/dists/stable/main/binary-$(uname -m)/Contents-$(uname -m).gz"
        "/dists/stable/main/binary-$(uname -m)/Contents-$(uname -m).gz"
        # Add more potential paths as needed
    )

    for path in "${paths[@]}"; do
        test_url="https://$mirror$path"
        status_code=$(curl -o /dev/null -s -w "%{http_code}" "$test_url")
        if [[ $status_code -eq 200 ]]; then
            echo "$test_url"
            return
        fi
    done

    echo ""
}

while true; do
    # Clear the screen
    clear

    # Find directories in the specified path
    DIRS=($(find "$PREFIX/etc/termux/mirrors" -mindepth 1 -maxdepth 1 -type d))

    # Check if any directories are found
    if [ ${#DIRS[@]} -eq 0 ]; then
        echo "No directories found in $PREFIX/etc/termux/mirrors."
        exit 1
    fi

    # Present directories as options to the user
    echo "Select a mirror to speed test:"
    for i in "${!DIRS[@]}"; do
        echo "$((i + 1)). ${DIRS[$i]#$PREFIX/etc/termux/mirrors/}"
    done
    echo "q. Quit"

    # Read user input (single character)
    read -n 1 -p "Enter your choice: " choice
    echo

    # Handle user input
    if [[ "$choice" == "q" ]]; then
        echo "Exiting..."
        exit 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#DIRS[@]} ]; then
        selected_dir="${DIRS[$((choice - 1))]}"
        clear

        # Extract and test the mirrors from the selected directory
        mirrors=($(find "$selected_dir" -type f -printf '%f\n'))
        fastest_time=999999
        fastest_mirror=""

        for mirror in "${mirrors[@]}"; do
            case $mirror in
                "gnlug.org")
                    test_url="https://gnlug.org/pub/termux/termux-main/dists/stable/Contents-$(uname -m).gz"
                    ;;
                "mirror.mwt.me")
                    test_url="https://mirror.mwt.me/termux/main/dists/stable/Contents-$(uname -m).gz"
                    ;;
                *)
                    test_url=$(find_valid_url "$mirror")
                    ;;
            esac

            if [[ -n "$test_url" ]]; then
                echo "Testing mirror: $mirror"
                read size_mb avg_time <<< $(speed_test_mirror "$test_url")
                echo "Size: $size_mb MB"
                echo "Time: $avg_time seconds"
                if (( $(echo "$avg_time < $fastest_time" | bc -l) )); then
                    fastest_time=$avg_time
                    fastest_mirror=$mirror
                fi
            else
                echo "No valid URL found for mirror: $mirror"
            fi
        done

        if [[ -n "$fastest_mirror" ]]; then
            echo "Fastest mirror: $fastest_mirror with time $fastest_time seconds"

            # Update sources.list with the fastest mirror
            update_sources_list "$fastest_mirror"
            echo "Updated $PREFIX/etc/apt/sources.list with the fastest mirror."
        else
            echo "No valid mirrors found."
        fi

        read -p "Press Enter to return to the main screen..."
    else
        echo "Invalid choice. Please try again."
        read -p "Press Enter to return to the main screen..."
    fi
done
