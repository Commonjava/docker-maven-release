#!/bin/bash -l

release=Y
if [ ! -e /home/maven/.ssh/id_rsa ]; then
  echo "Cannot find SSH key. Check that you specified \"-v /path/to/ssh:/home/maven/.ssh\""
  release=N
fi

if [ ! -e /home/maven/.m2/settings.xml ]; then
  echo "Cannot find Maven settings.xml. Check that you specified \"-v /path/to/m2:/home/maven/.m2\""
  release=N
fi

if [ ! -e /home/maven/.gnupg/gpg.conf ]; then
  echo "Cannot find GPG config file. Check that you specified \"-v /path/to/gnupg:/home/maven/.gnupg\""
  release=N
fi

if [ "${release}" != "Y" ]; then
    echo "Release cannot proceed."
    exit 1
fi

mkdir -p $HOME/projects
cd $HOME/projects

branch=${GIT_BRANCH:-master}
name=`basename $GIT`
name=${name%".git"}

git clone --branch $branch $GIT $name || exit 2
cd $name

/home/maven/apache-maven/bin/mvn -V clean release:prepare release:perform "$@" 2>&1 | tee build.log
