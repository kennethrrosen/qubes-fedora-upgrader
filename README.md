# qubes-fedora-upgrader
Simple dom0 bash script to streamline updating Fedora templates to latest releases

The script follows the procedure of in-place upgrading for an installed Fedora Template in your Qubes system. If you wish to install a new, unmodified Fedora template instead of upgrading a template that's already installed in your system, just issue `qvm-template install fedora-XX` or `qvm-template install fedora-XX-minimal`

The script begins by asking the user for the name of the template they want to upgrade. Then it checks if that template exists. If it does, the script extracts the current version of the Fedora release from the template and prompts the user if they wish to proceed with the upgrade. If the user agrees, the script then calculates the new version number and asks if the user wants to clone the template before upgrading. The user can choose to clone the template and provide a new name, or proceed with upgrading the original template.

The script then performs an initial upgrade and handles the distro-sync process. The script creates a cache block to prevent exiting over a "No space left on device" error.

Finally, after the upgrade is successful, it cleans up the expect package, performs additional updates and upgrades, and shuts down the template. Note: disk drimming is skipped as it should no longer be necessary.

### Usage

To use this script, copy to dom0 (check the script first) and then you've two options, one for single template upgrade and one for multiple template upgrades:

For single templates, run the below and you'll be prompted for the desired template:
```
./fed_upgrade.sh
```

```
./fed_upgrade.sh template1 template2 template3
```
