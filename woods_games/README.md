# README

## Add JS Packages
yarn add <package>

## Docker/Deployment
Running in `us-west-1`.

```
docker build -t rails_games .


# local testing (need to make credentials available somehow....)
docker run -p 3000:80 -e AWS_REGION=us-west-1  rails_games

# See boostnote for command to run w/ credentials

```

The ../deploy folder has a CDK project that defines a fargate service.  Run `cdk deploy` to update.
It will build the Dockerfile from this directory, which packages all changes - it produces a url for
the LoadBalancer as output.

Note: when using a new DDB table, the CDK project needs to be updated to grant access to the taskRole.

### Current TODOs
x the ziddler settings are getting strings instead of booleans and failing updates.
* the ziddler static files were moved into app/assets.  Make sure that they work server side as well.

* Re-enable setInterval to refreshGame data.
* Create index.html.erb for both games (to support the /ziddler index)

Current problem:

* The drag and drop for discarding does not pick up the deck space.  Trying to log in table.jsx