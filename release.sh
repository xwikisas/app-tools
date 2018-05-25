#!/bin/bash

function release_all() {
  init
  check_env
  prepare_extensions_to_release

  # If the Licensing version is still not provided, ask for it. (this is the case when something failed after the Licensing was released and needs to be skipped)
	if [[ -z $LICENSING_VERSION ]]; then
    echo -e "Which version of the \033[1;32mapplication-licensing\033[0m should be used as dependency in the paid apps?\033[0;32m"
    read -e -p "> " LICENSING_VERSION
    echo -n -e "\033[0m"
    export LICENSING_VERSION=$LICENSING_VERSION
  fi

  for i in "${!extensions[@]}"
  do
    release_project $i ${extensions[$i]}
  done
}

function prepare_extensions_to_release() {
  declare -gA extensions
  # Prepare the licensing app first
  check_versions application-licensing
  extensions[application-licensing]="${VERSION} ${NEXT_SNAPSHOT_VERSION} ${DO_RELEASE}"
  clear_versions

  for d in *; do
    if [[ -d $d ]] && [ $d != application-licensing ]; then
      check_versions $d
      extensions[$d]="${VERSION} ${NEXT_SNAPSHOT_VERSION} ${DO_RELEASE}"
      clear_versions
    fi
  done
}

function init() {
  echo -e "\033[0;32m* Initialization\033[0m"
  # Release from master branch
  RELEASE_FROM_BRANCH=master
}

function check_env() {
  echo -e "\033[0;32m* Checking environment\033[0m"
  # Check that we're in the right directory (contains licensing application)
  if [[ ! -d application-licensing ]]; then
    echo -e "\033[1;31mPlease go to the PayingApps directory where the sources are checked out\033[0m"
    exit -1
  fi
}

function release_project() {
  do_release=$4
  if [[ $do_release ]]; then
    APP_NAME=$1
    APP_VERSION=$2
    APP_SNAPSHOT_VERSION=$3
    echo              "*****************************"
    echo -e "\033[1;32m    Releasing $APP_NAME\033[0m"
    echo              "*****************************"
    cd $APP_NAME
    pre_cleanup
    update_sources
    if [ $APP_NAME != application-licensing ]; then
      update_licensing_version
    fi
    PROJECT_NAME=`mvn help:evaluate -Dexpression='project.artifactId' -N | grep -v '\[' | grep -v 'Download'`
    TAG_NAME=${PROJECT_NAME}-${APP_VERSION}
    # Set the name of the release branch
    RELEASE_BRANCH=release-${APP_VERSION}
    create_release_branch
    release_maven
    push_release
    post_cleanup
    push_tag
    cd ..
  fi
}

function check_versions() {
  DO_RELEASE="Yes"
  APP_NAME=$1
  echo -e "Do you want to release the \033[1;32m${APP_NAME}\033[0m?"
  read -e -p "Yes/No (${DO_RELEASE})> " do_release
  if [[ $do_release ]]
  then
    DO_RELEASE=${do_release}
  fi
  export DO_RELEASE=$DO_RELEASE
  if [ $DO_RELEASE = "Yes" ]; then
    # Check version to release
    if [[ -z $VERSION ]]
    then
      cd $APP_NAME
        CURRENT_VERSION=`mvn help:evaluate -Dexpression='project.version' -N | grep -v '\[' | grep -v 'Download' | cut -d- -f1`
        LATEST_TAG=`git describe --abbrev=0 --tags`
        LATEST_TAG_VERSION=${LATEST_TAG##*-}
      cd ..
      echo -e "Which version of the \033[1;32m${APP_NAME}\033[0m are you releasing?\033[0;32m"
      read -e -p "> Last released version: ${LATEST_TAG_VERSION}. Press Enter to release (${CURRENT_VERSION})> " current_version
      echo -n -e "\033[0m"
      if [[ $current_version ]]
      then
        CURRENT_VERSION=${current_version}
      fi
      export VERSION=$CURRENT_VERSION
    fi
    # Set the licensing version to be updated in the paying apps pom (initialized when the licensing app is released)
    if [[ $1 = application-licensing ]]
    then
      export LICENSING_VERSION=$VERSION
    fi

    # Check next SNAPSHOT version
    if [[ -z $NEXT_SNAPSHOT_VERSION ]]
    then
      VERSION_STUB=`echo $VERSION | cut -c1-3`
      let NEXT_SNAPSHOT_VERSION=`echo ${VERSION_STUB} | cut -d. -f2`+1
      NEXT_SNAPSHOT_VERSION=`echo ${VERSION_STUB} | cut -d. -f1`.${NEXT_SNAPSHOT_VERSION}-SNAPSHOT
      echo -e "What is the next SNAPSHOT version of the \033[1;32m${APP_NAME}\033[0m?"
      read -e -p "${NEXT_SNAPSHOT_VERSION}> " tmp
      if [[ $tmp ]]
      then
        NEXT_SNAPSHOT_VERSION=${tmp}
      fi
      export NEXT_SNAPSHOT_VERSION=$NEXT_SNAPSHOT_VERSION
    fi
  fi
}

function update_licensing_version() {
  echo -e "\033[0;32m* Updating <licensing.version> to ${LICENSING_VERSION}\033[0m"
  sed -e "s/<licensing.version>.*<\/licensing.version>/<licensing.version>${LICENSING_VERSION}<\/licensing.version>/" -i pom.xml
  git add pom.xml
  git commit -m "[release] Update licensing.version to ${LICENSING_VERSION}" -q
  git push origin $RELEASE_FROM_BRANCH
}

# Clean up the sources, discarding any changes in the local workspace not found in the local git clone and switching back to the master branch.
function pre_cleanup() {
  echo -e "\033[0;32m* Cleaning up\033[0m"
  git reset --hard -q
  git checkout master -q
  git reset --hard -q
  git clean -dxfq
}

# Fetch sources to synchronize the local git clone with the upstream repository.
function update_sources() {
  echo -e "\033[0;32m* Fetching latest sources\033[0m"
  git pull --rebase -q
  git clean -dxf
}

# Create a temporary branch to be used for the release, starting from the branch detected by check_branch() and set in the RELEASE_FROM_BRANCH variable.
function create_release_branch() {
  echo -e "\033[0;32m* Creating release branch\033[0m"
  git branch ${RELEASE_BRANCH} origin/${RELEASE_FROM_BRANCH} || exit -2
  git checkout ${RELEASE_BRANCH} -q
}

# Perform the actual maven release.
# Invoke mvn release:prepare, followed by mvn release:perform, then create a git tag.
function release_maven() {
  echo -e "\033[0;32m* release:prepare\033[0m"
  mvn release:prepare -DpushChanges=false -DlocalCheckout=true -DreleaseVersion=${APP_VERSION} -DdevelopmentVersion=${APP_SNAPSHOT_VERSION} -Dtag=${TAG_NAME} -DautoVersionSubmodules=true -Pintegration-tests -Darguments="-N -DskipTests" -DskipTests || exit -2

  echo -e "\033[0;32m* release:perform\033[0m"
  mvn release:perform -DpushChanges=false -DlocalCheckout=true -Pintegration-tests -Darguments="-DskipTests -Pintegration-tests" -DskipTests || exit -2

  echo -e "\033[0;32m* Creating tag\033[0m"
  git checkout ${TAG_NAME} -q
  git tag -s -f -m "Tagging ${TAG_NAME}" ${TAG_NAME}
}

# Push changes made to the release branch (new SNAPSHOT version, etc)
function push_release() {
  echo -e "\033[0;32m* Switch to release base branch\033[0m"
  git checkout ${RELEASE_FROM_BRANCH}
  echo -e "\033[0;32m* Merge release branch\033[0m"
  git merge ${RELEASE_BRANCH}
  echo -e "\033[0;32m* Push release base branch\033[0m"
  git push origin ${RELEASE_FROM_BRANCH}
}

# Cleanup sources again, after the release.
function post_cleanup() {
  echo -e "\033[0;32m* Cleanup\033[0m"
  git reset --hard -q
  git checkout master -q
  # Delete the release branch
  git branch -D ${RELEASE_BRANCH}
  git reset --hard -q
  git clean -dxfq
}

# Push the tag to the upstream repository.
function push_tag() {
  echo -e "\033[0;32m* Pushing tag\033[0m"
  git push --tags
}

function clear_versions() {
  export VERSION=""
  export NEXT_SNAPSHOT_VERSION=""
}

release_all