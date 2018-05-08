#!/bin/bash
CURRENT_LOCATION=`pwd`
echo -e "\033[0;32mWhere should the Paid apps be cloned? (e.g.: /home/user/Git/PaidApps)\033[0m"
appsListFile=`find . -name 'apps-list.txt'`
read -e -p "> (${CURRENT_LOCATION}): " location
if [[ $location ]]; then
  CURRENT_LOCATION=$location
fi
cd $CURRENT_LOCATION
while read p; do
  git clone git@github.com:xwikisas/${p}.git
done <$appsListFile
