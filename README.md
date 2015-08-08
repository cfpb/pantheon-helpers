# Pantheon Helpers

[![Build Status](https://travis-ci.org/cfpb/pantheon-helpers.svg?branch=master)](https://travis-ci.org/cfpb/pantheon-helpers)

[![Coverage Status](https://coveralls.io/repos/cfpb/pantheon-helpers/badge.svg)](https://coveralls.io/r/cfpb/pantheon-helpers)

## Description
The CFPB Pantheon of microservices help medium-sized development teams get their work done.
Pantheon Helpers is a small Node.js library to make it easier to build a microservice in Node.js with CouchDB.

## Features
This library makes it easy to build an application with the following features:

  * auditing
  * validation
  * rapid developement with a build script, and helpers for useful CouchDB and async promise patterns
  * asyncronous server actions to provide snappy api response times even when the actions kicked off by the api take a long time

Pantheon helpers provide a framework for handling "actions".
You:
  1. Define the actions your application will perform.
  2. Write an pure action transform function for each action. 
     The transform function takes an action and a CouchDB document,
     and idempotently transforms the document as required by the action.
  3. Write a pure validation function for each action.
     The validation function takes the action,
     the user who performed the action (the actor),
     and the old and new doc.
     It throws an error if the action was invalid or unauthorized.
  4. Write an asyncronous worker handler for any actions that result in side-effects. 
     The worker handler will be called _after_ the document has been written to the database,
     and _after_ a response has been sent to the client performing the action.
     The worker handler can run any slow, asyncronous code that the user shouldn't have to wait to complete before getting a response.
       For instance, updating a remote server with data uploaded by the action.

Pantheon provides all the plumbing to ensure that these functions are run at the right time,
in response to the right action,
have the expected result,
and are logged.

## Installation

In your microservice application's home directory, run:

    npm install git+https://github.com/cfpb/pantheon-helpers.git

    npm install -g coffee-script


## Lifecycle of an action

1) Perform an action:

```coffeescript
doAction = require('./doAction')
doAction(dbName, actorName, docId, {a: 'action name', ...})
```

dbName is only required if you don't specify it in `src/doAction`.
The actorName is the name (not ID) of the user performing the action.
The docId is the ID of the document to be modified,
null if the action creates a new document.
`actorName` and `docId` can alternatively be the document from the database.
If you've already grabbed the document from the db this can save a round trip to the db to grab it a second time.

The action hash must contain an `a` key with the action name,
and it may contain any other keys/values needed to perform the action.
It may not contain the following reserved keys:
`dt` (datetime stamp), `u` (user performing action),
and `id` (uuid of the action).

`doAction` will return a promise with the document as modified by the action.

2) `doAction` grabs the user document and the document to be opperated on, if you didn't already pass them in.

3) It grabs the action handler based on the document type and the action name (the `a` key in the action hash). Actions are defined in the `./actions.coffee` file.

4) The action handler receives the existing document
(or a skeleton document if it needs to create a new doc),
the action hash passed into doAction,
and the user who performed the action 
The action handler DOES NOT RETURN ANYTHING.
It must modify the passed document (and action hash if desired) in place.
Any errors thrown here will be propagated,
but you should NOT to validation/authentication/authorization here,
is it occurs in a subsequent step.

5) If the action handler modified the document,
then the do_action update handler adds the action to the audit entry. 
If the document was not modified,
then the unmodified document is return as the response for `doAction`.

6) If the action modified the document,
then doAction next calls the the `validateDocUpdate` function which, in turn calls the validation function defined for the action.
Validation functions are defined in `./validation.coffee`.

7) The validation function is passed the action hash,
the user that performed the action,
the document as it was before the action handler modified it,
and the document as modified by the action handler.
The validation function can perform any validation logic it wants given these inputs.
If the action as performed by the user was not valid or was unauthorized,
the validation function should throw an error hash. 
For an unauthorized action: 
`{state: 'unauthorized', err: 'descriptive error message'}`,
for an invalid action:
`{state: 'invalid', err: 'descriptive error message'}`

8a) If the validation function fails,
the document will not be modified,
and `doAction` will return an unauthorized or invalid error.

8b) If the validation function succeeds,
`doAction` will save the modified document and return the updated document.

9) The worker process is constantly watching the database for changes.
When the document is saved,
the worker process will wake up,
determine which actions in the audit log have not been handled by the worker yet,
and call the appropriate worker handler for each action.
Just like action handlers and validation functions,
worker handlers are defined for each document type and action in `./worker.coffee`.

10) The worker handler is passed the action and the document.
The worker should do anything that has side effects/takes a long time,
such as spinning up a service, calling another api endpoint, etc.
Whatever is done MUST BE IDEMPOTENT. 
There is no guarantee that the action will only be run through a worker once.
The worker must return a Promise.
If the worker fails,
or partially fails,
at whatever it is trying to do,
it should return a rejected promise.
If it succeeds completely, it should return a resolved promise.

11) If the worker handler failed,
then the returned error will be logged,
and the action will me marked as failed so it can be retried at a later time.
The time to retry will be 1 minute for the first failure,
then 2, 4, 8, 16... for subsequent failures.
If the worker succeeded,
then the action will be marked as successful, so it is not tried again.
Regardless of whether the worker handler succeeded or failed,
if the value of the Promise returned by the worker handler is a hash that includes a `data` hash and a `path` array,
then the data hash will be merged with the hash in the document at path,
and the resulting document will be saved to the database.


## Usage
For the remainder of this guide,
we will be creating a microservice called "Sisyphus" in the directory `$SISYPHUS`.
If you would like to follow along,
create a directory for the project and run:

    export $SISYPHUS=/path/to/sisyphus/directory

Our microservice will have endpoints to let us:

  * create a boulder
  * start rolling the boulder up the hill
  * set the boulder rolling back down the hill
  * get the current state of the boulder

The boulder will take 2 minutes to roll uphill,
at which point it will escape Sisyphus 
and roll down the hill for 20 seconds.
Then the whole process can start over again.

### 1. Set up directory structure
There should already be a node_modules directory with pantheon-helpers within it.
If not, follow the installation instructions, above.

Execute the pantheon-helpers bootstrap script:

    $SISYPHUS/node_modules/pantheon-helpers/bootstrap

You should now have the following directory structure:

    $SISYPHUS
      |- Cakefile: build tool. Run `cake` within $SISYPHUS
         to see available commands and arguments
      |- spec: jasmine tests go here; recreate the src 
         directory structure to make it easy to find tests
          |- apis: tests for api route handlers go here
          |- design_docs: tests for design docs go here
      |- src: coffeescript source files go here
          |- config.coffee: configuration variables
          |- config_secret.coffee: secret config variables;
             ignored by git; imported by config.coffee
          |- couch_utils.coffee: couch utilities, bound to the
             couchdb instance defined in your config files
          |- loggers.coffee: web and worker [bunyan](https://github.com/trentm/node-bunyan) loggers,
             configurable via `config.LOGGERS.WEB` and `config.LOGGERS.WORKER`.
             You will need to modify your config to send the logs to the appropriate location
             (usually a file when in production).
          |- app.coffee: executing this file starts the
             web server
          |- actions.coffee: action handlers (transform the document given an action) for each of your actions go here
          |- doAction.coffee: file defining doAction methods for each of your databases.
          |- validation.coffee: validation functions to validate each type of valid action go here.
          |- worker.coffee: executing this file starts
             any/all backround workers
          |- apis: api route handlers go here
          |- design_docs: files to be imported by Kanso into CouchDB design docs go here
              |- pantheon: a symlink to a kanso design doc to support such things as
                 retrying failed actions, and audit queries.
          |- .gitignore: ignores config_secret

      |- lib: javascript compiled from ./src by 
              `cake build` will go here
          |- design_docs: some coffeescript 
             generated by `cake start_design_doc` will
             go here

To complete the setup, 
You will need to set your CouchDB config variables so Sisyphus can access CouchDB in either:

 * $SISYPHUS/src/config.coffee
 * $SISYPHUS/src/config_secret.coffee

system username --
the username your application uses to log into CouchDB
-- and the CouchDB password that user uses.
However, you should not do this manually.
Instead, you should use the cfpb/pantheon ansible scripts.
See that repo's README for more info.


### 2. Getting ready to work
Run `cake watch`. This will watch for changes to .coffee files and compile them to javascript.


### 3. Set up your CouchDB database
#### CouchDB credentials
Add your CouchDB credentials to $SISYPHUS/src/config.coffee and $SISYPHUS/src/config_secret.coffee. You will need to specify a system username and a global password with which to access couchdb. Make sure the password is in config_secret.coffee.

You should see that the `cake watch` recompiles both config files as soon as you save them. 
If you don't use `cake watch` you will need to run `cake build` every time you make a change.

Now, we need to create the database in CouchDB.
Go to `localhost:5984/_utils`, click "Create Database",
and create a database called `boulders`.
Replace `localhost:5984` with the host/port for your CouchDB instance.
You may need to have an admin create the database for you.


#### Design documents
We use [Kanso](http://kan.so/) to load Design Docs into CouchDB. 
Design Docs let us run custom code on CouchDB in a fashion similar to stored procedures in RDBMSs.
You should [familiarize yourself with CouchDB Design Docs](http://guide.couchdb.org/draft/design.html), if you are not already.

A CouchDB instance can have many databases. Each database can have
many design docs. It can become difficult to ensure design docs remain
up-to-date across all databases. Pantheon-helpers helps you manage your design docs.

To create a new design doc, run:

    cake start_design_doc

and enter `boulder` for name and `base boulder DB design doc` for description.

Now we have a skeleton design doc in `$SISYPHUS/src/design_docs/boulder`. 
The `$SISYPHUS/src/design_docs/boulder/lib/app.coffee` is the primary entry point into your
design doc.
If you take a look, it has placeholders for some of the more common design document features.

If you look in `$SISYPHUS/lib/design_docs/boulder`,
you will see some files that have no corresponding .coffee file in `$SISYPHUS/src`.
First, is the `kanso.json` file, 
this is similar to node.js `package.json` or a bower `bower.json` file.
It tells kanso what to package up and send to couchdb.

Next is the `_security` file.
This is a json file that couchdb uses to manage permissions.
See http://docs.couchdb.org/en/latest/intro/security.html and
http://docs.couchdb.org/en/latest/api/database/security.html.
You should note that only the security document from the
first design doc defined for each database will be loaded.

Finally, in the `lib` subdirectory you will see a copy of underscore,
a symlink to the `pantheon-helpers/lib/design_docs` folder,
and a symlink to the `$SISYPHUS/lib/shared` file that lets you share application code between Node and CouchDB.
If you want to share other files between the two systems, just create additional symlinks here.
Any files that you want to reference in your design doc must be in the `$SISYPHUS/lib/design_docs/boulder` directory,
otherwise Kanso can't package them up.

Now that we have created our design document,
we have associate it with a type of database.
To do this, we create a new file at
$SISYPHUS/src/design_docs/boulders.coffee with the following contents:

    module.exports = ['boulder', 'pantheon']

This tells Pantheon to add the `boulder` design doc to every
single database that is (1) called `boulders` 
or (2) starts with `boulders_`.
If we wanted all those databases to also have another design doc installed, 
we would add the name of the desired design doc to the exported array.

Now that we have created our design doc, we need to sync it with CouchDB. Just run

    Cake sync_design_docs

This will update all the design documents in all your CouchDB databases.

### 3. Design the Sisyphus microservice
Rolling the boulder up the hill takes a long time (in web time): 2 minutes. 
When we make a request to roll the boulder up the hill,
we do not want to have to wait two minutes for a response.
Instead, we would like to receive a response instantly that our request to roll the boulder up the hill has been accepted and is being processed.
Then we want a background process to actually roll the boulder up the hill for two minutes.

Pantheon-helpers makes it easy to build this sort of decoupled application.
First, let's figure out what our data is going to look like,
then let's figure out what actions we want to be able to perform on that data.
Finally, we'll implement everything.

Our boulder is going to be represented by a json document.
We want to know whether it's rolling up the hill,
rolling down the hill, or at the bottom of the hill.
We're also curious about Zeus's reaction to events as they unfold.
We'll store Zeus's reaction to the most recent action right in the boulder document.
Thus, our json document will look like this:

    { "_id": "boulder_<boulder_id>"
    , "status": "rolling up|rolling down|at bottom"
    , "zeus": 
      { "is": "expectant|delighted|satisfied|mirthful|vengeful"
      }
    }

That's pretty easy! 

We are going to need to transform our boulder document in four different ways:

  1. create a new boulder (`b+`)
  2. start rolling the boulder up the hill (`bu`)
  3. make the boulder slip away and roll back down the hill (`bd`)
  4. bring the boulder to rest at the bottom of the hill (`br`)

Obviously, we can never destroy a boulder since this is an eternal (sysiphean, even) task.
Note that not all of these actions correspond to an endpoint. 
For example,
a `br` will only ever be called by a worker handling a `bd` event.


### 4. Testing
Testing is easy because the system is loosely coupled,
and each function you write 
(with the exception of worker handlers)
should have no side effects.

Because it is so easy, you should be writing a ton of tests.

You run your tests with `cake test`.
You will be writing your tests using jasmine-node,
so you will need to write tests against the [v1.3 api](http://jasmine.github.io/1.3/introduction.html).

You should set up $SISYPHUS/spec to mirror your $SISYPHUS/src directory.
Tests for, e.g., $SISYPHUS/src/design_docs/boulder/lib/app.coffee 
should go in $SISYPHUS/src/design_docs/boulder/lib/appSpec.coffee.
The `Spec` suffix is needed so jasmine-node can find your 

You should make liberal use of jasmine spys to mock and spy on external dependencies.

There is already a .travis.yml file in your project skeleton.
All you need to do is enable your repo on both travis-ci.org and coveralls.io.

### 5. Implement CouchDB actions

We need to:
  1. define how an action transforms the document (in `src/actions.coffee`), and
  2. define how to validate when an action is allowed (in `src/validation.coffee`)
  3. customize the doAction function for our application

Since most applications will have more than just one
document type, we define functions in relation to the
document type they can operate on.

In `src/actions.coffee`:

```coffeescript
# define our action handlers that will actually modify our doc
# in response to actions.
actionHandlers = {
  # we define all actions that can be performed on boulder docs
  boulder: {
    # an action is a function that receives the doc to be
    # acted on, the action to be performed, and the
    # user performing the action. It must update the
    # doc in place. The do_action framework ensures that the
    # document is saved only if the action handler actually
    # changed the document.
    'bu': (doc, action, actor) ->
      doc.status = 'rolling up'
    'bd': (doc, action, actor) ->
      doc.status = 'rolling down'
  }
  # we define all actions that create new docs here (since we 
  # wouldn't know the type of a new doc until after it is created)
  create: {
    'b+': (doc, action, actor) ->
      # by default, pantheon_helpers expects the type to be prepended to the id
      # the brand new doc passed into any create action handler
      # includes a brand new uuid at no extra cost.
      doc._id = 'boulder_' + doc._id
      doc.status = 'at bottom'
  }
}

module.exports = actionHandlers
```

In `src/validation.coffee`:

```coffeescript

# define our validation handlers that ensure that the action is valid.
validationFunctions = {
  # we define validation handlers for our boulder docs
  boulder: {
    # throw an error if the action is invalid;
    bu: (event, actor, oldDoc, newDoc) ->
      if oldDoc.status != 'at bottom'
        throw {
          state: 'invalid', 
          err: 'cannot start rolling boulder up until it reaches bottom'
        }
    bd: (event, actor, oldDoc, newDoc) ->
      if oldDoc.status != 'rolling up'
        throw {
          state: 'invalid',
          err: 'cannot roll down until boulder has started rolling up'
        }

    # You must define a validation function for all
    # valid actions, even if there is no validation logic.
    # Since b+ is always valid, we have an empty method.

    # Validation for b+ is under the boulder doc_type, 
    # because the action handler defined above has already
    # run and the boulder document has been created by this point.
    b+: (event, actor, oldDoc, newDoc) ->
  }
}

module.exports = validationFunctions
```

We have now defined how an action modifies a document, and we have defined when an action is valid.

A couple of notes:
  * Handler and validation functions cannot have any side effects.
    You can't make http requests or grab other documents.
  * Validation functions must throw either 
    {state: 'invalid', err: 'msg'} or {state: 'unauthorized', err: 'msg'}

Lastly, we need to customize our `doAction` method.
If you recall, doAction always returns the document as modified by the action. 
We want the returned data to include how far up the hill Sisyphus is with his boulder.
However, we don't want to store this in the boulder document since it will change moment by moment.
So we are going to create a prepDoc function that takes a document and prepares it for display.
We will dynamically calculate the boulder's position and add it to the document just before returning it to the user.

In `src/shared.coffee`:

```coffeescript
...

# If you are offended by the horrible hackiness
# of these calculations, you are encouraged to submit a 
# pull request.

s.prepDocsForDisplay = {
  boulder: (boulderDoc) ->
    # get the most recent action for this boulder
    last_action = boulderDoc.audit[boulderDoc.audit.length-1]

    now = +new Date()
    if not last_action or last_action.a = 'br'
      boulderDoc.hillPosition = 0

    else if last_action.a == 'bu'
      boulderDoc.hillPosition = Math.floor((now - last_action.dt)*.9/120, .9)

    else if last_action.a == 'bd'
      boulderDoc.hillPosition = Math.ceiling((now - last_action.dt)*.9/20, 0)
}

module.exports = s
```

A couple of notes: 
  * again, notice that we defined a different prepDoc function for each type of document that we store in our database.
  * We put prepDocthis file is called `shared.coffee` because it is available in from both Node and CouchDB.
  You can create other shared files by symlinking them into your design doc's `lib` folder at `$SISYPHUS/lib/design_docs/$DESIGNDOCNAME/lib`

Now, let's modify `src/doAction.coffee`: set `dbName = 'boulder'` so it modifies documents in the right database. 
If our application needed to perform actions on multiple databases we could leave `dbName = null`.
We would then have to specify the dbName as the first argument every time we performed an action.

There are several other functions you might need to modify for your own application in `shared.coffee` or `doAction.coffee`,
including `shouldSkipValidationForUser`, and `getDocType`.

If you need to perform actions on documents in multiple databases,
simply export two functions, one for each database.

Now that we have setUp `doAction`,
how do we actually use it?

```coffeescript  
# import our customized do_action method
doAction = require('./doAction')

# do the action, passing in the user document or name (NOT id), the document to modify or its id (or `null` if this action creates a new doc), and the action.

# create a boulder 
doAction('zeus', null, {a: 'b+'}).then((boulderDoc) ->
  # start rolling the boulder up the hill
  doAction('sisyphus', boulderDoc, {a: 'bu'})
)
```

As you can see, an action is just a dictionary.
The action name is specified by the `a` key.
You can use any other keys you like, with the
exception of the reserved system keys:
`dt` (datetime stamp), `u` (user performing action),
and `id` (uuid of the action)
The entire action dictionary is passed to your handler,
validation, and worker functions, and is stored in the
audit log.


### 6. Create background worker
Our actions now modify our document,
but they don't do anything in "real life".
Let's change that.

Our background worker watches the database for changes.
Whenever an event happens,
the Worker will find the appropriate worker function for that event
and call it.

In `$SISYPHUS/src/worker.coffee`:

```coffeescript
...

db = couch_utils.nano_system_user.use('boulders')

# return a promise, rather than using callbacks
doAction = require('pantheon-helpers/lib/doAction')
Promise = require('pantheon-helpers/lib/promise')

handlers: {
  # worker functions for boulder documents
  boulder:
    'bu': (event, doc, logger) ->
      # wait two minutes, then fire off a 'bd' event
      Promise.setTimeout(120000).next(() ->
        doAction(db, doc._id, {a: 'bd'})
      ).next(() ->
        # determine how Zeus felt about it
        zeus_response = _.sample([
          'delighted', 'satisfied', 'mirthful', 'vengeful'
        ])
        # return that Zeus's response so we can store in in doc.
        Promise.resolve({data: {is: zeus_response} path: ['zeus']})
      )
    'bd': (event, doc, logger) ->
      # wait 20 second, then fire off a 'br' event
      Promise.setTimeout(20000).next(() ->
        doAction(db, doc._id, {a: 'br'})
      ).next(() ->
        # determine how Zeus felt about it
        zeus_reaction = _.sample(['expectant'])
        # return Zeus's reaction so we can store in in doc.
        # note that we _must_ return a promise, not a raw value.
        # the value returned by a handler must be a dictionary
        # the object pointed to by path into the doc must also be a dict.
        # the object pointed to by path will be updated with the data dict's contents.
        Promise.resolve({data: {is: zeus_reaction}, path: ['zeus']})
      )
    # we don't need to do anything when a boulder is created or comes to rest
    'b+': null
    'br': null
}

...
```

A couple things:
  * Worker handlers MUST return a promise.
  * Any `data` returned in the promise will be merged into the
    document at the specified `path`. 
    Thus both `data` and the object at `path` must be hashes.
  * If your worker handler errors out, then the event will be marked
    as having errored.
    While not implemented yet,
    pantheon-helpers will eventually log the exact error and retry at a later time
  * **logging:** 
    The fact that your handler has been called,
    as well as the response and state (resolved/rejected),
    is logged by pantheon helpers.
    If you want to log additional information, 
    you can use the logger,
    which is passed as the third argument to your worker handler.
    You can create a log entry by making a call such as `logger.info({optional: 'metadata'}, 'log msg')`.
    See https://github.com/trentm/node-bunyan for full documentation.
    The relevant metadata linking your log entry to the particular document/revision action with which it is being called has already been included in the logger, s
    o you do not have to add this metadata.

### 7. Create the API
To have a working app, now all we need to do is set up our api.

One of the great things about CouchDB and Node, is that both handle http natively.
We can use Node to pipe responses from CouchDB straight back to the browser very efficiently.


We have two endpoints: `/boulders` and `boulders/:boulderId`.
We will correspondingly implement our route handlers in
`$SISYPHUS/src/api/boulders.coffee`
and `$SISYPHUS/src/api/boulder.coffee`.

In `$SISYPHUS/src/api/boulders.coffee`:

```coffeescript  
doAction = require('../doAction')
Promise = require('pantheon-helpers').Promise

b = {}

b.createBoulder = (actor) ->
  return doAction(actor, null, {a: 'b+'})

b.handleCreateBoulder = (req, resp) ->
  actor = req.session.user
  promise = b.createBoulder(actor)
  Promise.sendHttp(promise, resp)

module.exports = b
```

Let's unpack this a bit. 
We created two functions:
`createBoulder` and `handleCreateBoulder`.
This is a convention used throughout the pantheon. 
The plain `createBoulder` does the actual work.
The `handleCreateBoulder` handles an http request by calling `createBoulder`.
This way, you can perform api actions within your application without
making an http request. It also makes testing easier.

`handleCreateBoulder` gets the user making the request from the Express session.
It passes this to `b.createBoulder` to actually do the work.
`pantheon-helpers.promise.sendHttp` sends a successfully resolved promise back as the response, or it formats a standardized error and sends back a response with the `errorCode` specified in the error, or a 500.


When we `GET` a document, we want the boulder prepDoc function to run.
Since prepDocs is defined in `src/shared.coffee` it is available in the design doc we created at the very beginning of this tutorial. 
`pantheon-helpers` defines several useful helpers for lists and shows,
as well as several common lists and shows.
We will use the `prepped` show to return a document run through the `prepDoc` function.

In `$SISYPHUS/src/design_docs/boulder/lib/app.coffee`:

```coffeescript
...

  shows: {
    get_prepped: helpers.get_prepped

...
```


In `$SISYPHUS/src/api/boulder.coffee`:

```coffeescript
doAction = require('../doAction')
utils = require('pantheon-helpers').utils

b = {}

b.getBoulder = (db, boulderId, callback) ->
  boulderId = utils.formatId(boulderId)
  return db.show('boulder', 'get_prepped', boulderId, callback)

b.handleGetBoulder = (req, resp) ->
  db = req.couch.use('boulder')
  boulderId = req.params.boulderId
  b.getBoulder(db, boulderId).pipe(resp)

b.rollBoulderUp = (actor, boulderId) ->
  boulderId = utils.formatId(boulderId)
  return doAction(actor, boulderId, {a: 'bu'})

b.handleRollBoulderUp = (req, resp) ->
  actor = req.session.user
  boulderId = req.params.boulderId
  promise = b.rollBoulderUp(actor, boulderId)
  Promise.sendHttp(promise, resp)

b.rollBoulderDown = (actor, boulderId) ->
  boulderId = utils.formatId(boulderId)
  return doAction(actor, boulderId, {a: 'bd'})

b.handleRollBoulderDown = (req, resp) ->
  actor = req.session.user
  boulderId = req.params.boulderId
  promise = b.rollBoulderDown(actor, boulderId)
  Promise.sendHttp(promise, resp)

module.exports = b
```

A couple of notes:

`req.couch` is a couch client bound to the Express authenticated user.
The CouchDB Client is nano-promise, 
which is exactly the same as [nano](https://github.com/dscape/nano),
except that if you pass the string 'promise' instead of a callback it will return a promise instead of a pipable stream.

You'll notice that `b.handleGetBoulder` did not pass a callback to `b.getBoulder`.
`b.getBoulder` just returns whatever is returned by nano-promise.
By not passing anything as the callback, it returns a stream.
We can then pipe that response directly to our response object.
This is very memory efficient. 
Node does not have to receive the entire couch response into memory before sending it to the client. 
Instead, it just acts as a proxy, forwarding the CouchDB response to the client as it is received.
Had we passed the string 'promise', it would have returned a promise, and we would have had to receive the entire result, then passed it to `Promise.sendHttp()`.

With our route handlers created, we just need to create our routes:

In `$SISYPHUS/routes.coffee`:

```coffeescript
auditRoutes = require('pantheon-helpers').auditRoutes
boulders = require('./api/boulders')
boulder = require('./api/boulder')

module.exports = (app) ->
  app.post('/sisyphus/boulders/', boulders.handleCreateBoulder)

  app.get('/sisyphus/boulders/:boulderId', boulder.handleGetBoulder)
  app.put('/sisyphus/boulders/:boulderId/state/down', boulder.handleRollBoulderDown)
  app.put('/sisyphus/boulders/:boulderId/state/up', boulder.handleRollBoulderUp)

  auditRoutes(app, ['boulder'], '/sysiphus')
```

In addition to adding the sysiphus-specific routes,
we also added the audit query endpoint.
We had to specify all the CouchDB databases the endpoint should query for audit entries.
We also had to specify the audit route's prefix.
The `auditRoutes` function adds a single endpoint `<prefix>/audit`, which accepts a `start` and `end` query params with unix timestamp (`+new Date()`) - e.g.: `/sisyphus/audit/?start=1438203622727&end=1438205772727`

You now have a fully functioning application with auditing, logging, and a background worker process.

Thanks for reading!
