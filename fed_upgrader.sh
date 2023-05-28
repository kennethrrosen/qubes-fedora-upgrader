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
    
    message "Allocating additional space..."
    truncate -s 5GB /var/tmp/template-upgrade-cache.img
    dev=$(sudo losetup -f --show /var/tmp/template-upgrade-cache.img)
    
    message "Attaching block to $new_template_name"
    qvm-start $new_template_name
    qvm-block attach $new_template_name dom0:${dev##*/}
    qvm-run -p $new_template_name "sudo mkfs.ext4 /dev/xvdi"
    qvm-run -p $new_template_name "sudo mount /dev/xvdi /mnt/removable"
    
    message "Performing upgrade. Patience..."
    if qvm-run -p $new_template_name "sudo dnf clean all && sudo dnf --releasever=$new_num distro-sync --best --allowerasing -y";
    then
        qvm-run -p $new_template_name "sudo dnf update -y && sudo dnf upgrade -y"
        qvm-run -p $new_template_name "cat /etc/fedora-release"
        qvm-shutdown $new_template_name
        message "Upgrade completed successfully!"
        message "Upgrade completed successfully!"
        sleep 2
        message "Removing temporary cache..."
        sleep 2
        sudo losetup -d $dev
        rm -f /var/tmp/template-upgrade-cache.img
    else
        message "Upgrade failed. Check the template for issues."
        exit 1
    fi
}

prompt_user() {
    current_version=$(qvm-run -p $template "cat /etc/fedora-release")
    current_num=$(echo $current_version | grep -oP '(\d+)')
    message "Current version of $template is: Fedora release $current_num ${YELLOW} "
    read -p "Proceed with the upgrade? (y/n): " proceed
    if [[ $proceed != "y" ]]; then
        message "Skipping $template without changes."
        exit 0
    fi
    read -p "Do you want to clone the template before upgrading? (y/n): " clone
}

get_new_template_name() {
    if [[ $clone == "y" ]]; then
        read -p "What should be the new template name? " new_template_name
        echo $new_template_name
    else
        echo $1
    fi
}

if [ $# -gt 0 ]; then
    for template in "$@"; do
        prompt_user
        new_template_name=$(get_new_template_name $template)
        upgrade_template $template $proceed $clone $new_template_name
    done
else
    read -p "What template do you want to upgrade? " template
    prompt_user
    new_template_name=$(get_new_template_name $template)
    upgrade_template $template $proceed $clone $new_template_name
fi
