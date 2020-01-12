#!/bin/bash

# Use this deploy to deploy API ENDPOINTS TO GOOGLE STORAGE

#source ./environment

PROJECT=ionoid
BUCKET=api.ionoid.net
dir=install-ionoid

echo "Checking git status: please commit and push upstream any pending changes"
git status

echo ""
echo "Deploying ionoid install-tools to Google Storage Project $PROJECT bucket $BUCKET"

currentproject=$(gcloud config get-value project)

if [ "$currentproject" != "$PROJECT" ]; then
        gcloud config set project $PROJECT
        echo "gcloud switched from $currentproject to $PROJECT"
fi

gsutil -m cp install-ionoid-sealos-manager-sdk.bash gs://api.ionoid.net/$dir/
gsutil -m cp install-tools.bash gs://api.ionoid.net/$dir/
gsutil -m cp build-os.bash gs://api.ionoid.net/$dir/
gsutil -m cp ionoid-parse-machine.bash gs://api.ionoid.net/$dir/
gsutil -m cp LICENSE gs://api.ionoid.net/$dir/
gsutil -m cp README.md gs://api.ionoid.net/$dir/

gsutil -m cp -r ./post-build.d gs://api.ionoid.net/$dir/

# Make files accessible publicly
gsutil -m acl -r ch -u AllUsers:R gs://api.ionoid.net/$dir

if [ "$currentproject" != "$PROJECT" ]; then
        gcloud config set project $currentproject
        echo "gcloud switched back from $PROJECT to $currentproject"
fi

exit 0
