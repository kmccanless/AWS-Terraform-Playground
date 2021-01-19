WIP repo using Terraform that reates network, elasticache, RDS Aurora Serverless db, ecs container, and bastion and other resources. Uses some external 
modules and also develops modules for other resources.  Not all resources use the module pattern yet.  
Shows how to use Keybase for secrets.  Also, how to push environment variables into CircleCi from TF.  Note:  since discovered a plugin to 
push env vars to CircleCI so opting for it.
 

Run "ln -s /Keybase/PathTo/Keys ." to add SSH keys stored in Keybase to the project

Run the following command to create the SSM/SSH tunnel. Watch the key, instance id, database url, profile, and region for issues.
```
ssh -i  ~/Documents/AWS/keys/test-acct-1. \
-Nf -M \
-L 9090:km-development-database.cluster-csnj5u8hrwsl.us-east-2.rds.amazonaws.com:3306 \
-o "UserKnownHostsFile=/dev/null" \
-o "StrictHostKeyChecking=no" \
-o ProxyCommand="aws ssm start-session --profile=test-acct-1-admin --target %h --document AWS-StartSSHSession  --parameters portNumber=%p --region=us-east-2" \
ec2-user@i-01aabfc5309f6e2e5

```

