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

## Current TODOs
### Word Mine
x Add colors to cards (based on deck/rarity)
* Add a game log




## Bonus Words designs

Dynamo table with bonus words
indexing? 
We need to read all the words for a list at once (why? only to display a page with the words for someone to check)
so either:
1. 1 table per word list, then do a read all. PK=word
2. PK=list_name, SK=word

For scoring - we dont need to load the list into memory - we can query it during each round scoring.
its a quick/optimized call, 1 per word to check.

How can we add to the list?
Permissions model?  Voting?


And are lists specific to game rooms??
