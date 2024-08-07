#!/data/data/com.termux/files/usr/bin/bash

# Global variables
CONFIG_FILE="/data/data/com.termux/files/home/android_device_config.txt"

# Function to check and retrieve command output
get_command_output() {
    local command_output
    if ! command_output=$("$@"); then
        printf "Error executing command: %s\n" "$*" >&2
        return 1
    fi
    printf "%s" "$command_output"
}

# Function to retrieve device info
get_device_info() {
    local device_info
    if ! device_info=$(get_command_output getprop); then
        return 1
    fi
    printf "%s\n" "$device_info"
}

# Function to retrieve kernel version
get_kernel_version() {
    local kernel_version
    if ! kernel_version=$(get_command_output uname -r); then
        return 1
    fi
    printf "Kernel Version: %s\n" "$kernel_version"
}

# Function to retrieve CPU info
get_cpu_info() {
    local cpu_info
    if ! cpu_info=$(get_command_output cat /proc/cpuinfo); then
        return 1
    fi
    printf "%s\n" "$cpu_info"
}

# Function to retrieve memory info
get_mem_info() {
    local mem_info
    if ! mem_info=$(get_command_output cat /proc/meminfo); then
        return 1
    fi
    printf "%s\n" "$mem_info"
}

# Function to retrieve storage info
get_storage_info() {
    local storage_info
    if ! storage_info=$(get_command_output df -h); then
        return 1
    fi
    printf "%s\n" "$storage_info"
}

# Function to retrieve battery info using Termux's Battery Status
get_battery_info() {
    local battery_info
    if ! battery_info=$(get_command_output termux-battery-status); then
        return 1
    fi
    printf "%s\n" "$battery_info"
}

# Function to retrieve network info
get_network_info() {
    local network_info
    if ! network_info=$(get_command_output ifconfig); then
        return 1
    fi
    printf "%s\n" "$network_info"
}

# Function to write configuration to file
write_config_to_file() {
    {
        printf "Device Configuration:\n\n"
        printf "Device Info:\n"
        get_device_info || return 1
        printf "\nKernel Version:\n"
        get_kernel_version || return 1
        printf "\nCPU Info:\n"
        get_cpu_info || return 1
        printf "\nMemory Info:\n"
        get_mem_info || return 1
        printf "\nStorage Info:\n"
        get_storage_info || return 1
        printf "\nBattery Info:\n"
        get_battery_info || return 1
        printf "\nNetwork Info:\n"
        get_network_info || return 1
    } > "$CONFIG_FILE"
}

# Main function
main() {
    if ! write_config_to_file; then
        printf "Failed to write device configuration to file\n" >&2
        return 1
    fi
    printf "Device configuration written to %s\n" "$CONFIG_FILE"
}

main "$@"
