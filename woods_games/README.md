# README

## Add JS Packages
yarn add <package>

## Docker/Deployment
Running in `us-west-1`.

```
rails s
./bin/webpack-dev-server
```

```
docker build -t rails_games .


# local testing (need to make credentials available somehow....)
docker run -p 3000:80 -e AWS_REGION=us-west-1  rails_games

# See boostnote for command to run w/ credentials

```

Note - may need to delete the Gemfile.lock. (platform errors)

The ../deploy folder has a CDK project that defines a fargate service.  Run `cdk deploy` to update.
It will build the Dockerfile from this directory, which packages all changes - it produces a url for
the LoadBalancer as output.



Ensure Docker Desktop is running (required for cdk deploy to build the docker image)

Then from deploy:
```shell
AWS_REGION=us-west-1 cdk deploy
```

This will use the Dockerfile and build the local assets, produce a new image and then upload it.

Note: when using a new DDB table, the CDK project needs to be updated to grant access to the taskRole.

### Current TODOs
x Fix formatting of rooms page (center)
x remove logging of get state (remove log pollution)

Ziddler todos:
x new game at end does not work
x sort animal word list
x"I've got nothing" button
* Bonus - Rethink bonus word lists entirely [they should allow for user management.... maybe voting?]
