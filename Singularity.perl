Bootstrap: docker
From: zakame/perl:5.32-alpine

%labels
  Maintainer foo@bar.com
  Version 0.0.999

%setup
   echo export BUILDER_REPOSITORY_VERSION="$(git rev-parse --verify --short HEAD)"       > .builderinfo
   echo export BUILDER_REPOSITORY_NAME="$(basename "$(git rev-parse --show-toplevel)")" >> .builderinfo
   echo export BUILDER_REPOSITORY_URL="$(git remote get-url origin)"                    >> .builderinfo

%files
  .builderinfo /opt/.builderinfo
  app-commands /opt/app-commands
  cpanfile /opt/cpanfile

%environment
  export LC_ALL=C
  export PATH=/opt/local/bin:$PATH
  export PERL5OPT=-I/opt/local/lib/perl5
  
%post
  cd /opt
  ## record builder details
  cat .builderinfo >> $SINGULARITY_ENVIRONMENT && rm .builderinfo

  ## install / update system dependencies
  apk --update add --no-cache --virtual .build-deps build-base ca-certificates curl git make openssl tar
  apk --update add --no-cache --virtual .runtime tar

  ## Build
  cpanm -L local --installdeps -n -q .
  rm cpanfile

  ## cleanup  
  apk del .build-deps

%runscript
  SINGULARITY_BASENAME=$(basename $SINGULARITY_NAME .sif)

  if echo $SINGULARITY_BASENAME | grep -qxf /opt/app-commands; then
    exec /opt/local/bin/$SINGULARITY_NAME "$@"
  else
    /bin/echo -e "This Singularity image cannot provide a single entrypoint. Please use \"singularity exec $SINGULARITY_NAME <cmd>\", where <cmd> is one of the following:\n"
    exec cat /opt/app-commands
  fi
