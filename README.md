# Applications Tools

Scripts and tools to manage, build and release paid apps.

## GitHub Issue Labels

New paid apps should reuse the issue labels defined in the ``github-issue-labels.json`` file. Use [git-labelmaker](https://github.com/himynameisdave/git-labelmaker) to import the labels. You need to select "Remove All Labels" first and then "Add Labels From Package".

## Jenkins Pipeline

The ``vars`` folder contains the Jenkins pipeline library shared by all paid app builds. The entry point is the ``xwikisasModule`` that paid apps should use in their ``Jenkinsfile``.

## Clone Apps

All the apps involved in the Paid Apps mechanism can be cloned at once, in a specified directory, by using the `clone-apps.sh` script. This will read the apps' names from the `appsList.txt` file. 
