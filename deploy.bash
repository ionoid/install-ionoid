#!/bin/bash

# Use this deploy script to deploy the tools to a remote server

# tools are assumed to be in /var/www/$SERVER/tools/$TARGET/

source ./environment

echo "Checking git status: please commit and push upstream any pending changes"
git status

echo ""
echo "Deploying  $TARGET  -  to Server $SERVER"

# Lets clean previous deployments
ssh -p $SSHPORT $USER@$SERVER rm -fr $TARGET
ssh -p $SSHPORT $USER@$SERVER mkdir -p $TARGET

# Prepare filesystem
ssh -p $SSHPORT $USER@$SERVER sudo mkdir -p /var/www/${SERVER}/tools/${TARGET}/

scp -pr -P $SSHPORT install-ionoid-sealos-manager-sdk.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT install-tools.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT build-os.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT ionoid-parse-machine.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT LICENSE $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT README.md $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT post-build.d $USER@$SERVER:~/${TARGET}

ssh -p $SSHPORT $USER@$SERVER sudo -E cp -f -r $HOME/${TARGET} /var/www/${SERVER}/tools/

# Lets fix permissions in cases
ssh -p $SSHPORT $USER@$SERVER sudo chown -R www-data.www-data /var/www/${SERVER}/tools/${TARGET}/

./deploy-to-google-cloud.bash

exit 0
