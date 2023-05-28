#!/bin/env bash
# A simple script for updating Fedora templates in QubesOS

PREFIX="$(tput setaf 7)$(tput bold)"
YELLOW="$(tput setaf 3)$(tput bold)"
POSTFIX="$(tput sgr0)"
TAB="$(echo -e '\t')"
ENTER=""

message() {
    echo "${PREFIX}${1}${POSTFIX}"
}

upgrade_template() {
    local template=$1
    local proceed=$2
    local clone=$3
    local new_template_name=$4

    vm_exists=$(qvm-ls | grep -w "$template")
    if [[ -z $vm_exists ]]; then
        message "Template $template does not exist."
        exit 1
    fi

    current_version=$(qvm-run -p $template "cat /etc/fedora-release")
    current_num=$(echo $current_version | grep -oP '(\d+)')
    message "Current version of $template is: Fedora release $current_num ${YELLOW} "

    if [[ $proceed != "y" ]]; then
        message "Skipping $template without changes."
        return 0
    fi

    new_num=$((current_num + 1))
    new_release="fedora-$new_num"

    if [[ $clone == "y" ]]; then
        qvm-clone $template $new_template_name
    else
        new_template_name=$template
    fi

    message "Performing upgrade..."
    upgrade_status=$(qvm-run -p $new_template_name "sudo dnf --releasever=$new_num distro-sync --best --allowerasing -y")
    
    message "Checking for space errors..."
    if [[ $upgrade_status == *"No space left on device"* ]]; then
        message "Insufficient disk space, creating cache in dom0 and retrying..."
        truncate -s 5GB /var/tmp/template-upgrade-cache.img
        dev=$(sudo losetup -f --show /var/tmp/template-upgrade-cache.img)
        qvm-block attach $new_template_name dom0:${dev##*/}
        qvm-run -p $new_template_name "sudo mkfs.ext4 /dev/xvdi"
        qvm-run -p $new_template_name "sudo mount /dev/xvdi /mnt/removable"
        qvm-run -p $new_template_name "sudo dnf clean all"
        upgrade_status=$(qvm-run -p $new_template_name "sudo dnf --releasever=$new_num --setopt=cachedir=/mnt/removable --best --allowerasing distro-sync -y")
        sudo losetup -d $dev
        rm -f /var/tmp/template-upgrade-cache.img
    fi

    if [[ $upgrade_status != *"Complete!"* ]]; then
        message "Upgrade failed. Check the template for issues."
        exit 1
    else
        qvm-run -p $new_template_name "cat /etc/fedora-release"
        # Presently this script skips trimming as this should no longer be necessary
        # qvm-run -p $new_template_name "sudo fstrim -av"
        qvm-run -p $new_template_name "sudo dnf update -y && sudo dnf upgrade -y"
        qvm-shutdown $new_template_name
        message "Upgrade completed successfully!"
    fi
}

if [ $# -gt 0 ]; then
    current_version=$(qvm-run -p $template "cat /etc/fedora-release")
    current_num=$(echo $current_version | grep -oP '(\d+)')
    message "Current version of $template is: Fedora release $current_num ${YELLOW} "
    read -p "Proceed with the upgrade for all templates? (y/n): " proceed
    if [[ $proceed != "y" ]]; then
        message "Skipping $template without changes."
        return 0
    fi
    read -p "Do you want to clone the templates before upgrading? (y/n): " clone
    if [[ $clone == "y" ]]; then
        read -p "What should be the new template name prefix? " new_template_name_prefix
    fi
    for template in "$@"; do
        if [[ $clone == "y" ]]; then
            new_template_name="${new_template_name_prefix}_$template"
        else
            new_template_name=$template
        fi
        upgrade_template $template $proceed $clone $new_template_name
    done
else
    read -p "What template do you want to upgrade? " template
    current_version=$(qvm-run -p $template "cat /etc/fedora-release")
    current_num=$(echo $current_version | grep -oP '(\d+)')
    message "Current version of $template is: Fedora release $current_num ${YELLOW} "
    read -p "Proceed with the upgrade? (y/n): " proceed
    if [[ $proceed != "y" ]]; then
        message "Skipping $template without changes."
        return 0
    fi
    read -p "Do you want to clone the template before upgrading? (y/n): " clone
    if [[ $clone == "y" ]]; then
        read -p "What should be the new template name? " new_template_name
    else
        new_template_name=$template
    fi
    upgrade_template $template $proceed $clone $new_template_name
fi

