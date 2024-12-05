#!/bin/bash

# Global constants
readonly SYSTEM_VOLUME_IDENTIFIER="disk2s5"
readonly DATA_VOLUME_IDENTIFIER="disk2s1"

# Text formatting
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Defines the path to a volume with the given disk identifier
defineVolumePath() {
    local diskIdentifier=$1

    # Check if the volume is mounted
    volumePath=$(diskutil info "$diskIdentifier" | grep "Mount Point" | awk -F': ' '{print $2}')
    if [ -z "$volumePath" ]; then
        # Attempt to mount the volume if not mounted
        echo -e "${BLUE}Mounting volume $diskIdentifier...${NC}"
        diskutil mount "$diskIdentifier"
        volumePath=$(diskutil info "$diskIdentifier" | grep "Mount Point" | awk -F': ' '{print $2}')
    fi

    echo "$volumePath"
}

# Main logic for the script
echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo -e "${YELLOW}* Check MDM - Skip MDM Auto for macOS by  *${NC}"
echo -e "${RED}*             SKIPMDM.COM                 *${NC}"
echo -e "${RED}*            Phoenix Team                 *${NC}"
echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo ""

PS3='Please enter your choice: '
options=("Autobypass on Recovery" "Check MDM Enrollment" "Reboot" "Exit")

select opt in "${options[@]}"; do
    case $opt in
    "Autobypass on Recovery")
        echo -e "\n\t${GREEN}Bypass on Recovery${NC}\n"

        # Get volume paths
        systemVolumePath=$(defineVolumePath "$SYSTEM_VOLUME_IDENTIFIER")
        dataVolumePath=$(defineVolumePath "$DATA_VOLUME_IDENTIFIER")

        echo -e "${GREEN}System Volume Path: $systemVolumePath${NC}"
        echo -e "${GREEN}Data Volume Path: $dataVolumePath${NC}\n"

        # Check if volumes are valid
        if [ -z "$systemVolumePath" ] || [ -z "$dataVolumePath" ]; then
            echo -e "${RED}Error: Could not find required volumes. Ensure the volumes are mounted and accessible.${NC}"
            break
        fi

        # Create User
        echo -e "${BLUE}Checking user existence...${NC}"
        dscl_path="$dataVolumePath/private/var/db/dslocal/nodes/Default"
        localUserDirPath="/Local/Default/Users"
        defaultUID="501"

        if ! dscl -f "$dscl_path" localhost -list "$localUserDirPath" UniqueID | grep -q "\<$defaultUID\>"; then
            echo -e "${CYAN}Creating a new user${NC}"
            echo -e "${CYAN}Enter Full Name (default: Apple):${NC}"
            read -rp "Full name: " fullName
            fullName="${fullName:=Apple}"

            echo -e "${CYAN}Enter Username (default: Apple):${NC}"
            read -rp "Username: " username
            username="${username:=Apple}"

            echo -e "${CYAN}Enter Password (default: 4 spaces):${NC}"
            read -rsp "Password: " userPassword
            userPassword="${userPassword:=    }"

            echo -e "\n${BLUE}Creating User...${NC}"
            dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username"
            dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UserShell "/bin/zsh"
            dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" RealName "$fullName"
            dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UniqueID "$defaultUID"
            dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" PrimaryGroupID "20"
            mkdir "$dataVolumePath/Users/$username"
            dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" NFSHomeDirectory "/Users/$username"
            dscl -f "$dscl_path" localhost -passwd "$localUserDirPath/$username" "$userPassword"
            dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"
            echo -e "${GREEN}User created successfully!${NC}\n"
        else
            echo -e "${BLUE}User already exists.${NC}\n"
        fi

        # Block MDM hosts
        echo -e "${BLUE}Blocking MDM hosts...${NC}"
        hostsPath="$systemVolumePath/etc/hosts"
        blockedDomains=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")
        for domain in "${blockedDomains[@]}"; do
            echo "0.0.0.0 $domain" >>"$hostsPath"
        done
        echo -e "${GREEN}MDM hosts blocked successfully.${NC}\n"

        # Remove config profiles
        echo -e "${BLUE}Removing config profiles...${NC}"
        configProfilesSettingsPath="$systemVolumePath/var/db/ConfigurationProfiles/Settings"
        touch "$dataVolumePath/private/var/db/.AppleSetupDone"
        rm -rf "$configProfilesSettingsPath/.cloudConfigHasActivationRecord"
        rm -rf "$configProfilesSettingsPath/.cloudConfigRecordFound"
        touch "$configProfilesSettingsPath/.cloudConfigProfileInstalled"
        touch "$configProfilesSettingsPath/.cloudConfigRecordNotFound"
        echo -e "${GREEN}Config profiles removed successfully.${NC}\n"

        echo -e "${GREEN}------ Autobypass Completed Successfully ------${NC}"
        echo -e "${CYAN}------ Exit Terminal and Reboot Your Mac ------${NC}"
        break
        ;;

    "Check MDM Enrollment")
        if [ ! -f /usr/bin/profiles ]; then
            echo -e "\n\t${RED}Don't use this option in recovery.${NC}\n"
            continue
        fi

        if ! sudo profiles show -type enrollment >/dev/null 2>&1; then
            echo -e "\n\t${GREEN}MDM Enrollment Check Passed.${NC}\n"
        else
            echo -e "\n\t${RED}MDM Enrollment Check Failed.${NC}\n"
        fi
        ;;

    "Reboot")
        echo -e "\n\t${BLUE}Rebooting...${NC}\n"
        reboot
        ;;

    "Exit")
        echo -e "\n\t${BLUE}Exiting...${NC}\n"
        exit
        ;;

    *)
        echo "Invalid option $REPLY"
        ;;
    esac
done
