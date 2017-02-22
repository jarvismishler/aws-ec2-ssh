#!/bin/bash

# Specify an IAM group for users who should be given sudo privileges, or leave
# empty to not change sudo access, or give it the value '##ALL##' to have all
# users be given sudo rights.
SudoersGroup="${IAM_GRP_SUDOERS}"
[[ -z "$SudoersGroup" ]] || Sudoers=$(
  aws iam get-group --group-name "$SudoersGroup" --query "Users[].[UserName]" --output text
);

ShellAccessGroup="${IAM_GRP_SHELL_ACCESS}"
[[ -z "$ShellAccessGroup" ]] || ShellAccessUsers=$(
  aws iam get-group --group-name "$ShellAccessGroup" --query "Users[].[UserName]" --output text
);

aws iam list-users --query "Users[].[UserName]" --output text | while read User; do

  if [[ ! -z "$ShellAccessGroup" ]]; then
    SaveUserName="$User"
    SaveUserName=${SaveUserName//"+"/".plus."}
    SaveUserName=${SaveUserName//"="/".equal."}
    SaveUserName=${SaveUserName//","/".comma."}
    SaveUserName=${SaveUserName//"@"/".at."}
    if echo "$ShellAccessUsers" | grep "^$User\$" > /dev/null; then
      # This is a user with shell access
      if ! grep "^$SaveUserName:" /etc/passwd > /dev/null; then
        /usr/sbin/useradd --create-home --shell /bin/bash "$SaveUserName"
      fi

      # Lets check if this user should have sudo access
      if [[ ! -z "$SudoersGroup" ]]; then
        # sudo will read each file in /etc/sudoers.d, skipping file names that end
        # in ‘~’ or contain a ‘.’ character to avoid causing problems with package
        # manager or editor temporary/backup files.
        SaveUserFileName=$(echo "$SaveUserName" | tr "." " ")
        SaveUserSudoFilePath="/etc/sudoers.d/$SaveUserFileName"
        if echo "$Sudoers" | grep "^$User\$" > /dev/null; then
          echo "$SaveUserName ALL=(ALL) NOPASSWD:ALL" > "$SaveUserSudoFilePath"
        else
          [[ ! -f "$SaveUserSudoFilePath" ]] || rm "$SaveUserSudoFilePath"
        fi
      fi
    else
      # This is a user without shell access
      if grep "^$SaveUserName:" /etc/passwd > /dev/null; then
        # If the user looks like it still exists, lets kill it
        /usr/sbin/userdel -r "$SaveUserName"
        /usr/sbin/groupdel "$SaveUserName"
      fi
    fi
  fi
done
