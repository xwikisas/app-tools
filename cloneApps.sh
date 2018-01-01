#!/bin/bash
echo -e "\033[0;32mWhere should the Paid apps be cloned? (e.g.: /home/user/Git/PaidApps)\033[0m"
appsListFile=`find ~/ -name 'apps-list.txt'`
read -e -p "> " location
if [[ $location ]]; then
  cd $location
  while read p; do
    git clone git@github.com:xwikisas/${p}.git
  done <$appsListFile
else
  echo "Please specify the location!"
fi
