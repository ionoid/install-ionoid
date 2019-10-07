#!/bin/bash

source ./environment

echo "Checking git status: please commit and push upstream any pending changes"
git status

echo ""
echo "Deploying  $TARGET  -  to Server $SERVER"

# Lets clean previous deployments
ssh -p $SSHPORT $USER@$SERVER rm -fr $TARGET
ssh -p $SSHPORT $USER@$SERVER mkdir -p $TARGET

# Prepare filesystem
ssh -p $SSHPORT $USER@$SERVER sudo mkdir -p /mnt/storage/$SERVER/www/tools/${TARGET}/

scp -pr -P $SSHPORT install-ionoid-sealos-manager-sdk.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT install-tools.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT build-os.bash $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT LICENSE $USER@$SERVER:~/${TARGET}
scp -pr -P $SSHPORT README.md $USER@$SERVER:~/${TARGET}

ssh -p $SSHPORT $USER@$SERVER sudo -E cp -f -r $HOME/${TARGET}/ /mnt/storage/${SERVER}/www/tools/

# Lets fix permissions in cases
ssh -p $SSHPORT $USER@$SERVER sudo chown -R www-data.www-data /mnt/storage/$SERVER/www/tools/${TARGET}/

exit 0
