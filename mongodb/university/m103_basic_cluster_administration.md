# M103 Basic Cluster Administration


## The Mongod

Close mongod via mongosh:
```js
> use admin
> db.shutdownServer()
> exit
```

Config file example:
```yaml
storage:
  dbPath: "/var/lib/mongodb/"
systemLog:
  destination: "file"
  path: "/var/log/mongodb/mongod.log"
  logAppend: true
replication:
  replSetName: M103
net:
  bindIp : "127.0.0.1,192.168.103.100"
  port: 27017
  tls:
    mode: "requireTLS"
    certificateKeyFile: "/etc/tls/tls.pem"
    CAFile: "/etc/tls/TLSCA.pem"
security:
  authorization: enabled
  keyFile: "/data/keyfile"
processManagement:
  fork: true
  pidFilePath: /var/run/mongo.pid
```

### Basic Commands:
User management commands:
```js
> db.createUser()
> db.dropUser()
```
Collection management commands:
```js
> db.<collection>.renameCollection()
> db.<collection>.createIndex()
> db.<collection>.drop()
```
Database management commands:
```js
> db.dropDatabase()
> db.createCollection()
```
Database status command:
```js
> db.serverStatus()
```
Creating index with Database Command:
```js
> db.runCommand({
   "createIndexes":"<collection_name>",
       "indexes":[
          {
             "key":{ "product": 1 },
             "name": "name_index"
          }
       ]
    }
 )
```
Creating index with Shell Helper:
```js
> db.<collection>.createIndex(
  { "product": 1 },
  { "name": "name_index" }
)
```

### Logging
Process log displays activity on `mongod` instance and collects activity into
one of components, e.g. `ACCESS`, `CONTROL`, `SHARDING`, etc. Each component
has its own verbosity level.
Get the log components:
```js
> db.getLogComponents()
{
  "verbosity": 1,
  "accessControl": {"verbosity: -1"},  // -1 means inherited verbosity from parent
  "command": {"verbosity: -1"},
  "control": {"verbosity: -1"},
  "replication": {
    "verbosity": -1,
    "hearbeats": {"verbosity: -1"},
    "rollback": {"verbosity: -1"}
  }
  <much_more_compoents_here>
}
```
Verbosity levels
- -1: inherited from parent
- 0: informational messaged (default)
- 1 - 5: debug messages increasing verbosity
View the logs through the `mongosh`:
```js
> db.adminCommand({"getLog": "global"})
```
Change the log verbosity for the index component to zero:
```js
> db.setLogLevel(0, "index")
```
See log file, use `-f` to follow the updates in the file:
```shell
$ tail -f /var/log/mongodb/mongodb.log
```

### Profiling the Database
Log is for admins to watch the system health, profiler is for examining how
queries and commands on the data work.
Profiling level is set for each database individually and may be:
- 0 switched off
- 1 profiler collects data for slow operations (> 100ms) only
- 2 profiler collects data for all operation
Profiling data is written into `system.profile` collection. Turning the level to
`2` may result in _lots_ of info being written.
Get profiling level for a database
```js
> use new_db
> db.getProfilingLevel()
0
> db.setProfilingLevel(1)
{"was": 0, "slowms": 100, "sampleRate": 1, "ok": 1}
> db.runCommand({listCollections: 1})
system.profile
> db.setProfilingLevel(1, {slowms: 0})
{"was": 1, "slowms": 100, "sampleRate": 1, "ok": 1}
> db.new_collection.insertOne({"a": 1})
> db.system.profile.find().pretty()
<large_document_here>
> db.new_collection.findOne({"a": 1})
<another_large_document_here>
```

### Basic MongoDB Security:
Authentication -- user identity verification, determining who you are
Authorization -- determining the resources an authentication user can access
and operations on those resources she can conduct
MongoDB authentication machanisms:
- SCRAM (Salted Challenge Response Authentication Mechanism), password security
- X.509, certification based
- LDAP (Enterprise only)
- KERBEROS (Enterprise only)

Authorization: role base access control (RBAC)
- each user has one or more _role_
- each role has one or more _privileges_
- a privilege represents a group of _actions_ and _resources_ those actions
  apply to

User exist per database. In basic case, user is created in the `admin` database.

Localhost exception:
- Allows you to access a `mongod` server that enforces authentication but does
  not yet have a configured user for you to authentication with
- Must run `mongosh` from the _same host_ running the `mongod`
- The localhost exception closes after you create your first user
- Always create a user with administrative privileges first.

Create a superuser
```
$ mongosh --host 127.0.0.1:27017
> use admin
> db.createUser({user: "root", pwd: "root123", roles : ["root"]})
> exit
$ mongosh --username root --password root123 --authenticationDatabase admin
> db.stats()
> exit
```

### Built-in Roles:
Role is composed of:
- Set of privileges
  - actions -> resources
- Network authentication restrictions:
  - clientSource
  - serverAddress

Resource is one of:
- database
- collection
- set of collecitons
- cluster
  - replica set
  - shard cluster

Resource may be one of:
- specific database and collection: `{db: "products", collection: "inventory"}`
- all databases and all collections: `{db: "", collection: ""}`
- any database and specific collection: `{db: "", collection: "accounts"}`
- specific database any collection: `{db: "products", collection: ""}`
- cluster resource: `{cluster: true}`

Privilege = resouce + actions allowed over a resource, e.g.
`{resouce: {cluster: true}, actions: ["shutdown"]`.
A role can inherit one or several roles
Built-in Roles:
- Database User
  - read
  - readWrite
- Database Administration
  - dbAdmin
  - userAdmin
  - dbOwner
- Cluster Administration
  - clusterAdmin
  - clusterManager
  - clusterMonitor
  - hostManager
- Backup/Restore
  - backup
  - restore
- Super User
  - root

Roles are per database. But there are also roles which apply to all databases:
- Database User
  - readAnyDatabase
  - readWriteAnyDatabse
- Database Administration
  - dbAdminAnyDatabase
  - userAdminAnyDatabase
- Super User
  - root

Privileges of the `userAdmin` role (it can't read or write the actual data):
- changeCustomData
- changePassword
- createRole, createUser, dropRole, dropUser, viewRole, viewUser
- grantRole, revokeRole
- setAuthenticationRestriction

Privileges of the `dbAdmin` role (it can't write the actual data):
- collStats, collMod, dbHash, dbStats
- listCollections, listIndexes
- killCursors
- convertToCapped, compact, bypassDocumentValidation
- ...

The role `dbOwner` combines privileges of `readWrite`, `dbAdmin`, `userAdmin`.

All users should be created on the `admin` database even they are granted roles
on other databases (please see the `dba` user with `dbAdmin` on `m103` database).
Example:
```
$ mongosh -u root -p root123 --authenticationDatabase admin
> db.createUser({
  user: "security_officer",
  pwd: "h3ll0th3r3",
  roles: [{db: "admin", role: "userAdmin"}]
})
> db.createUser({ user: "dba",
  pwd: "c1lynd3rs",
  roles: [{db: "m103", role: "dbAdmin"}]
})
> db.grantRolesToUser("dba",  [{db: "playground", role: "dbOwner"}])
> db.runCommand({rolesInfo: {role: "dbOwner", db: "playground"}, showPrivileges: true})
```

### Server Tools Overview:
```shell
$ mongod --port 30000 --dbpath ~/first_mongod \
    --logpath ~/first_mongod/mongodb.log --fork
$ mongostat --help
$ mongostat --port 30000
<returns_stats_every_second>
```
The first six fields in the output represent number of operation per seconds,
next seven fields show memory statistics, where `dirty` is percentage of dirty
bytes in the cache, `used` - percentage of currently used bytes in the cache.

The `mongodump` and `mongorestore` tools are for exporting and importing dump
files which are in BSON format.
```shell
$ mongodump --help
$ mongodump --port 30000 \
  --user foo --password bar --authenticationDatabase admin \
  --db applicationData --collection products
$ ls dump/applicationData/
$ cat dump/applicationData/products.metadata.json
$
$ mongorestore --port 30000 \
    --user foo --password bar --authenticationDatabase admin --drop dump/
```
The `mongoexport` and `mongoimport` tools export and import the data in JSON
format.
```shell
$ mongoexport --help
$ mongoexport --port 30000 \
  --user foo --password bar --authenticationDatabase admin \
  --db applicationData --collection products -o products.json
$
$ tail products.json
$
$ mongoimport --port 30000 \
  --user foo --password bar --authenticationDatabase admin \
  --drop --db applicationData --collection products products.json
```


## Replication
Operation log (oplong) is a statement based log which keeps track of the all
write opertions acknoledged by the replica set. It keeps writes operations in
idempotent form.
Node types:
- primary: accepts writes
- secondary
- arbiter: hold no data, can vote in election, cannot become primay
- hidden: a seconday node which can provide specific read-only workload or be
  hidden from the application
- delayed: hidden with special delay in synchronization, resilience to the
  application level corruption

Majority of nodes have to be available in order for the primary to be elected.
That is why a 4-node replica set doesn't provide better availability that a
3-node one because on both configuration we can loose only one node. A replica
set may comprise up to 50 members, maximum 7 of which can be voting members.
A topology change (adding node, remove node, node failure, rs configuration
change) causes an election. Topology is defined on the one of the nodes and
shared between all the members through replication mechanism.

### Setting Up a Replica Set
Prepare the keyfile:
```shell
$ sudo mkdir -p /var/mongodb/pki/
$ sudo chown $USER:$USER /var/mongodb/pki/
$ openssl rand -base64 741 > /var/mongodb/pki/m103-keyfile
$ chmod 400 /var/mongodb/pki/m103-keyfile
```
Put configuration for the first node into the `node1.conf`. Note the
`security.keyFile` field and the `replication` subobject.
```yml
storage:
  dbPath: /var/mongodb/db/node1
net:
  bindIp: 192.168.103.100,localhost
  port: 27011
security:
  authorization: enabled
  keyFile: /var/mongodb/pki/m103-keyfile
systemLog:
  destination: file
  path: /var/mongodb/db/node1/mongod.log
  logAppend: true
processManagement:
  fork: true
replication:
  replSetName: m103-example
```
Prepare the configurations for the second and the third nodes in the files
`node2.conf` and `node3.conf`. They are essentially the same as for the first
node with minimal changes:
- in `node2.conf`:
  - `storage.dbpath` is `/var/mongodb/db/node2`
  - `net.port` is `27012`
  - `systemLog.path` is `/var/mongodb/db/node2/mongod.log`
- in `node2.conf`:
  - `storage.dbpath` is `/var/mongodb/db/node3`
  - `net.port` is `27013`
  - `systemLog.path` is `/var/mongodb/db/node3/mongod.log`

Create required directories, start the `mongod` processes, and initialize a
replica set
```shell
$ mkdir /var/mongodb/db/{node1,node2,node3}
$ mongod --config node1.conf
$ mongod --config node2.conf
$ mongod --config node3.conf
```
Now, there are three nodes running but they don't know about each other.
Connect to the first node, initiate a replica set and create a superuser:
```s
$ mongosh --port 27011
> rs.initiate()
> use admin
> db.createUser({user: "m103-admin",
    pwd: "m103-pass",
    roles: [{role: "root", db: "admin"}]
  })
> exit
```
Connect to the replica set member, not a standalone node (see the `m103-example`
replica set name in the host name). In that case, `mongosh` discovers which node
is the primary for the specified replica set and connects to that instead. In
this case, we have only one node in the set and that node is primary.
```
$ mongosh --host "m103-example/192.168.103.100:27011"  \
    -u "m103-admin" -p "m103-pass" --authenticationDatabase "admin"
> rs.status()
> rs.add("m103:27012")
> rs.add("m103:27013")
> rs.isMaster()
```
At this point, the nodes can replication data from one another. If you want
to trigger election, connect to the current primary node and step down:
```js
> rs.stepDown()
// election take a couple of moments, after that the shell connects us to the
// new primary where we can verity
> rs.isMaster()
```

### Replication Configuration Document and Replication Commands
The replication document excerpt:
```
{
  _id: m103-example,
  version: 17,
  members: [
    {
      _id: 1,
      host: m103:27011,
      arbiterOnly: false,
      hidden: false,
      priority: 1,
      slaveDelay: 0
    },
    ...
  ]
}
```

Replication Commands:
```js
> rs.status()
> rs.isMaster()
> db.serverStatus()['repl']
```
Command for return data about oplog. Note that oplog is a capped collection so
the earlies entry change over time.
```js
> rs.printReplicationInfo()
```

### Local DB
Connect to a fresh standalone MongoDB instance and see what databases are there:
```
$ mongosh <opts>
> show dbs
admin
local
> use local
> show collections
startup_log
```
Now connect to a replica set:
```
$ mongo <opts>
m103-example:PRIMARY> use local
m103-example:PRIMARY> show collections
me
oplog.rs
replset.election
replset.minvalid
startup_log
system.replset
system.roolback.id

```
The `oplog.rs` collection keeps track of statement being replicated it a replica
set. Every single piece of information and operations that need to be replicated
will be logged in this collection.
`oplog.rs` is a capped collection:
```
m103-example:PRIMARY> let stats = db.oplog.rs.stats()
m103-example:PRIMARY> stats.capped
true
m103-example:PRIMARY> stats.size
3284
m103-example:PRIMARY> stats.maxSize
NumberLong(1908275200)
```
Max size in megabytes:
```
m103-example:PRIMARY> let stats = db.oplog.rs.stats(1024 * 1024)
m103-example:PRIMARY> stats.maxSize
1819
````
By default `oplog.rs` takes 5% of the free disk space. That can be changed via
config file.
More info on `oplog.rs`:
```
m103-example:PRIMARY> rs.printReplicationInfo()
configured oplog size: 1819.87
log length start to end: 362secs (0.1hrs)
oplog first event time: Tue Feb 20 2018 23:03:39 GMT+0000 (UTC)
oplog last event time:  Tue Feb 20 2018 23:09:41 GMT+0000 (UTC)
now:                    Tue Feb 20 2018 23:09:44 GMT+0000 (UTC)
```
Every node in a replica set has its own oplog. Sink sources may have different
oplog sizes, e.g. primary node may have a bigger oplog. Given the idempodent
nature of the instructions, one single update my result in several operation
in the oplog. E.g.
```
m103-example:PRIMARY> use m103
m103-example:PRIMARY> db.createCollection('messages')
m103-example:PRIMARY> show collections
messages
m103-example:PRIMARY> use local
m103-example:PRIMARY> db.oplog.rs.find({"o.msg": {$ne: "periodic noop"}}).\
              sort({$natural: -1}).limit(1).pretty()
{
    ...
    "o": {
        "create": "messages",
        ...
    }
    ...
}
m103-example:PRIMARY> use m103
m103-example:PRIMARY> for ( i=0; i< 100; i++) { db.messages.insert( { 'msg': 'not yet', _id: i } ) }
m103-example:PRIMARY> db.messages.count()
100
m103-example:PRIMARY> use local
m103-example:PRIMARY> db.oplog.rs.find({"ns": "m103.messages"}).sort({$natural: -1})
{
  ...
  "op": "i",
  "o": {"_id": 80, "msg": "not yet"},
  ...
}
m103-example:PRIMARY> use m103
m103-example:PRIMARY> db.messages.updateMany( {}, { $set: { author: 'norberto' } } )
{"acknoledged": true, "matchedCount": 100, "modifiedCount": 100}
m103-example:PRIMARY> use local
m103-example:PRIMARY> db.oplog.rs.find( { "ns": "m103.messages" } ).sort( { $natural: -1 } )
{
    ...
    "op": "u",
    "o2": {"_id": 80},
    ...
}
{
    ...
    "op": "u",
    "o2": {"_id": 81},
    ...
}
```
One single single instruction `updateMany` on the primary produced 100
operations in the oplog.


### Reconfiguring a Replica Set
Adding a regular node and the arbiter to the replica set. Their configurations
(files `node2.conf` and `arbiter.conf` respectively) are the same as the
`node1.conf` file excpet
Configuration for the future fourth node of the replica set (file `node2.conf`)
is the same as the one for the fist three noded except:
- in `node4.conf`
  - `storage.dbpath` is `/var/mongodb/db/node4`
  - `net.port` is `27014`
  - `systemLog.path` is `/var/mongodb/db/node4/mongod.log`
-in `arbiter.conf`
  - `storage.dbpath` is `/var/mongodb/db/arbiter`
  - `net.port` is `28000`
  - `systemLog.path` is `/var/mongodb/db/arbiter/mongod.log`

Run the nodes:
```shell
$ mongod --config node4.conf
$ mongod --config arbiter.conf
```
Connect to the replica set and add the nodes:
```js
m103-example:PRIMARY> rs.add("m103.mongouniversity.com:27014")
m103-example:PRIMARY> rs.addArb("m103.mongouniversity.com:28000")
m103-example:PRIMARY> rs.isMaster()
{
    "hosts": [
        "192.168.103.100:27011",
        "m103.mongodb.university:27012",
        "m103.mongodb.university:27013",
        "m103.mongodb.university:27014",
    ],
    "arbiters": ["m103.mongodb.university:2800"],
    "primary": "m103.mongodb.university:27012",
    "me": "m103.mongodb.university:27012",
    ...
}
```
Remove the arbiter node:
```
m103-example:PRIMARY> rs.remove("m103.mongouniversity.com:28000")
```
Remove the voting privileges from one of the node so that will leave us with 3
voting memebers. In addition to be non-votin, that secondary is going to be a
hiddent node.
```
m103-example:PRIMARY> cfg = rs.conf()
m103-example:PRIMARY> cfg.members[3].votes = 0
m103-example:PRIMARY> cfg.members[3].hidden = true
m103-example:PRIMARY> cfg.members[3].priority = 0
m103-example:PRIMARY> rs.reconfig(cfg)
m103-example:PRIMARY> rs.conf()
```

### Reads and Writes on a Replica Set:
Connecting to the replica set:
```shell
$ mongo --host "m103-example/m103:27011" -u "m103-admin" -p "m103-pass" \
    --authenticationDatabase "admin"
```
Checking replica set topology:
```js
m103-example:PRIMARY> rs.isMaster()
{
    ...
    "primary": "192.168.103.100:27011",
    "me": "192.168.103.100:27011",
    ...
}
```
Inserting one document into a new collection:
```js
m103-example:PRIMARY> use newDB
m103-example:PRIMARY> db.new_collection.insert( { "student": "Matt Javaly", "grade": "A+" } )
```
Connecting directly to a secondary node (this node may not be a secondary
in your replica set!):
```shell
$ mongo --host "m103:27012" -u "m103-admin" -p "m103-pass" \
    --authenticationDatabase "admin"
```
Attempting to execute a read command on a secondary node (this should fail):
```
> show dbs
```
Enabling read commands on a secondary node:
```
> rs.slaveOk()
```
Reading from a secondary node:
```
> use newDB
> db.new_collection.find()
```
Attempting to write data directly to a secondary node (this should fail,
because we cannot write data directly to a secondary):
```
> db.new_collection.insert( { "student": "Norberto Leite", "grade": "B+" } )
```
Shutting down the server (on both secondary nodes)
```
> use admin
> db.shutdownServer()
```
Connecting directly to the last healthy node in our set:
```shell
$ mongo --host "m103:27011" -u "m103-admin" -p "m103-pass" \
    --authenticationDatabase "admin"
```
Verifying that the last node stepped down to become a secondary when a majority
of nodes in the set were not available:
```
> rs.isMaster()
```
At this point, writes are not possible to the replica set because there is no
primay. The latter is another fail-safe mechanism to ensure data consistency.


### Failover and Elections
Change priority of a node to zero so that it can not be elected as primary
```js
m103-example:PRIMARY> cfg = rs.conf()
m103-example:PRIMARY> cfg.members[2].priority = 0
m103-example:PRIMARY> rs.reconfig(cfg)
m103-example:PRIMARY> rs.isMaster()
{
    ...
    "hosts": [
        "192.168.103.100:27011",
        "m103.mongouniversity:27012"
    ],
    "passives": [
        "m103.mongouniversity:27013"
    ],
    "primary": "m103.mongodb.university:27011",
    "me": "m103.mongodb.university:27011",
    ...
}
```
Note the node with zero priority moved to the `passives` array. At this point,
if the current primary is steps down, the only real candidate for a new primary
is the nodo at port `27012`. Let's check that:
```js
m103-example:PRIMARY> rs.stepDown()
m103-example:PRIMARY> rs.isMaster()
{
    ...
    "hosts": [
        "192.168.103.100:27011",
        "m103.mongouniversity:27012"
    ],
    "passives": [
        "m103.mongouniversity:27013"
    ],
    "primary": "m103.mongodb.university:27012",
    "me": "m103.mongodb.university:27012",
    ...
}
```
Note. If the current primary can't reach the majority of the nodes in the
replica set, it automatically steps down to become a secondary. In a 3-node
replica set, majority is 2 nodes. If both secondaries go down, the primary
steps down. Since there is no majority of the nodes available, the election
can't take place until enogh nodes come back to form a majority. A replica set
in such a stage can't accept write operations for the sake of data consistency
and safety.

### Write Concerns
A write concern is a number of replica set members which acknoledge that
a write operation is successfull. The higher the write concern, the higher
the data durability/safety but the latency of the write operation can also
be higher.

Available write concert levels:
- 0 - Don't wait for acknowledgement
- 1 (default) - Wait for acknowledgment from the primary node only
- greater than 1 - Wait for acknowledgment from the primary and one or more
  secondaries
- "majority" - Wait for acknowledgment from a majority of replica set members

Write Concern Options:
- `wtimeout: <int>` - time to wait for the requested write concern before
  marking the operation as failed; failed operation doesn't mean the write
  didn't take place, it means the desired level of durability hasn't been
  achieved for the specified time.
- `j: <true|false>` - requires the node to commit the write operation to the
  journal before returning the acknowledgement; write concern `"majority"`
  implies `j: true`; with `j: false` write operation may exist only in the
  memory (not disk) and can still be acknowledged

Commands supporting write concern
- insert
- update
- delete
- findAndModify

Consider a 3-node replica set. With default write concert equal to 1, a client
application gets acknowledge when the write operation becomes successfull on the
primary even before that operation has been propagated to any of the
secondaries. At this point, if the primary goes down, then the write operation
_will be rolled back_ when the primary comes back. That is because the majority
of nodes didn't have a change to get that write operation yet.

If the write concern were set to "majority", then at least one seconday (apart
from the primary) has to receive the write operation before it is acknowledged
to the client application. In this configuration, there is no risk of rolling
back that write operation even if any number of nodes go down and then come
back.

Setting the write concern to the number of nodes in a replica set in an attempt
to achieve the best possible data durability is not a wise idea though. Not only
does it increase the write operation latency since more time is required for
the operation to propagate all the nodes before being acknowledged but it also
may block the acknoledgement completely if one of the secondaries goes down.
That is when the `wtimeout` option becomes handy.

### Read Concern
Checks whether the queried document meets the requested durability guarantee.
The read operation with the read concent returns only those document that
have the durability specified in the read concern.
Note. The document that does not meet the read concern is _not_ guaranteed to
be lost. That document hasn't propagated to the required number of nodes yet.

Read Concern Levels:
- `local` - returns the most recent data, all data written to the primary
  qualifies for the `local` read concern
- `available` differs from `local` only in sharded cluster context
- `majority`
- `linearizable` = `majority` + `read_your_own_write`

Choosing the read concern level depends on the client application architecture.
Choose two out of three following read properties: `LATEST`, `FAST` and `SAFE`:
- if application requires latest data and the fast read operations, choose
  `local` or `available`; that provides no durability guarantee though
- if application requires latest data and the safe read operations, choose
  `linearizable`; that level support single document reads only and the read
  operation are going to be slower
- if application requires fast and safe read operations, choose the `majority`
  level; read are not guarantee to return the latest data though

### Read Preference
Read preference allows an application to route the read to specific node of
replica set. It is a driver/mongosh setting.

Read Prefernce Modes:
- `primary` (default) - routes all the read operation to the primary node
- `primaryPreferred` - routes all the read operation to the primary node except
  the cases when primary is unavailable (e.g. during election)
- `secondary` - routes all the read operation to the secondary node
- `secondaryPreferred` - routes all the read operation to the secondary node
  except the cases when the secondary nodes are not available
- `nearest` - routes read operation to the replica set member with the least
  network latency regardless of the member's type.

All read prefernce modes except `primary` may result into the client receiving
stale data (even with `local`/`available` read concert) due to replication lag.
How stale the read data is depends on replication delay.

## Sharding
A shard keeps a portion of the whole data set. A shard is typically deployed as
a replica set for high availability. Clients connect the the routing process
`mongos` instead of connecting to each shard. The `mongos` process reads the
metadata about exact shard on which some piece of data is located from the
_config server_ which itself is a replica set for high availability.

Before changing the configuraiton from a signle replica set to a sharded
cluster, check economic viability of vertical scaling for more powerfull CPU,
RAM, network throughput and disk (or everything) depending on the workload.
Please note, that one expanding one resource may require respective expanding
another one. For instance, having 15x bigger dataset on the same machine
required 15x bigger disk but also:
01. has operational impact: 15x longer backup/restore/initial_sync which imposes
    bigger load on the network.
02. produces 15x time bigger indexes; not only does bigger index require
    15x more RAM, but it also slow down performance

Rule of thumb: individual server should contain 2 ~ 5 TB of data. Bigger
datasets become too time consuming to operate one. Besides that, some workload
naturally play better in distributed environment:
- signle thread operation, e.g. aggregation pipeline commands
- geographically distributed data, please see zone sharding.

### Setting up a sharded cluster
Prepare configs of configuration server replica set (CSRS):
```shell
$ cat csrs_1.conf
sharding:
  clusterRole: configsvr
replication:
  replSetName: m103-csrs
security:
  keyFile: /var/mongodb/pki/m103-keyfile
net:
  bindIp: localhost,192.168.103.100
  port: 26001
systemLog:
  destination: file
  path: /var/mongodb/db/csrs1.log
  logAppend: true
processManagement:
  fork: true
storage:
  dbPath: /var/mongodb/db/csrs1
```
Two other members of configuration replica set have very similar configs, the
changes from `csrs_1.conf` are:
- in the `csrs_2.conf` file
  - `net.port` changes to `26002`
  - `systemLog.path` changes to `/var/mongodb/db/csrs2.log`
  - `storage.dbPath` chagnes to `/var/mongodb/db/csrs2`
- in the `csrs_3.conf` file
  - `net.port` changes to `26003`
  - `systemLog.path` changes to `/var/mongodb/db/csrs3.log`
  - `storage.dbPath` chagnes to `/var/mongodb/db/csrs3`
Start the config servers
```shell
$ mongod -f csrs_1.conf
$ mongod -f csrs_2.conf
$ mongod -f csrs_3.conf
```
Connect to one of the config servers, initiate the replica set,
create super user on CSRS, authenticate as the super user,
add the second and third node to the CSRS
```
$ mongo --port 26001
> rs.initiate()
>
> use admin
> db.createUser({
    user: "m103-admin",
    pwd: "m103-pass",
    roles: [
      {role: "root", db: "admin"}
    ]
  })
>
> db.auth("m103-admin", "m103-pass")
>
m103-csrs:PRIMARY> rs.add("192.168.103.100:26002")
m103-csrs:PRIMARY> rs.add("192.168.103.100:26003")
```
Now the complete config server replica set is set up. One can verity that:
```
m103-csrs:PRIMARY> rs.isMaster()
{
    "hosts": [
        "192.168.103.100:26001",
        "192.168.103.100:26002",
        "192.168.103.100:26003"
    ],
    "primary": "192.168.103.100:26001",
    "me": "192.168.103.100:26001",
    ...
}
```
Now we need to start `mongos` and point it to the CSRS.
Prepare the mongos config. Note the mongos config doesn't have the `storage`
section:
```
$ cat mongos.conf
sharding:
  configDB: m103-csrs/192.168.103.100:26001,192.168.103.100:26002,192.168.103.100:26003
security:
  keyFile: /var/mongodb/pki/m103-keyfile
net:
  bindIp: localhost,192.168.103.100
  port: 26000
systemLog:
  destination: file
  path: /var/mongodb/db/mongos.log
  logAppend: true
processManagement:
  fork: true
```
Note that in the `sharding.configDB` field we specify the entire replica set
instead of individual members. `mongos` inherit the same users as config
servers. Start mongos server, connect to it and check sharding status:
```
$ mongos -f mongos.conf
$ mongo --port 26000 --username m103-admin --password m103-pass \
    --authenticationDatabase admin
mongos> sh.status()
...
shards:
active mongoses:
    "3.6.2-rc0": 1
...
```
Note that the `shards` field is empty since we don't have any connected shards
yet.

In order to connect the already existing `m103-exmaple` replica set to a sharded
cluster, extent each member config with the following:
```yml
sharding:
  clusterRole: shardsvr
```
Connect directly to a secondary node of the `m103-example` replica set,
shout down and restart it:
```
$ mongo --port 27012 -u "m103-admin" -p "m103-pass" --authenticationDatabase "admin"
m103-example:SECONDARY> use admin
m103-example:SECONDARY> db.shutdownServer()
$ mongod -f node2.conf
```
Do the same for the second secondary node.

Connect to the primary node, step down and restart it:
```
$ mongo --port 27011 -u "m103-admin" -p "m103-pass" --authenticationDatabase "admin"
m103-example:PRIMARY> rs.stepDown()
m103-example:SECONDARY>
m103-example:SECONDARY> use admin
m103-example:SECONDARY> db.shutdownServer()
$ mongod -f node1.conf
```
Now, sharding has been successfully enables on the replica set `m103-example`.
Connect to mongos and add the shard:
```
$ mongo --port 26000 -u m103-admin -p m103-pass --authenticationDatabase admin
mongos> sh.addShard("m103-example/192.168.103.100:27012")
mongos> sh.status()
...
shards:
    {"_id": "m103-example", "host": "m103-example/192.168.103.100:27011,192.168.103.100:27012,192.168.103.100:27013", "state": 1}
active mongoses:
    "3.6.2-rc0": 1
...
```
Note that it is enough to specify one node in the
`sh.addShard(<replica_set_name>/<node_host>)` in order for `mongos` to discover
the current primary of the replica set.

### Config DB
Never write any data to configuration db! But reading from theere may give
useful information. In fact, some output of `sh.status()` is actually from
that database.
```
mongos> use config
mongos> show collections
actionlog
changelog
chunks
...
databases
...
```
By `primary` in the output of `db.databases.find().pretty()` the primary shard
is ment.
```
mongos> db.databases.find().pretty()
{"_id": "m103", "primary": "m103-example", "partitioned": true}
```
The `db.collections.find()` gives information about sharded collections. The
`key` field is the sharding key. The `unique` field tells if the key is unique.
```
mongos> db.collections.find().pretty()
...
{
    "_id": "m103.products",
    "key": {"salePrice": 1},
    "unique": false,
    ...
}
...
```
The `db.shards.find()` command, as the name suggest, return information about
shards. Below the host names below constain replica set names because the
shards were deployed as replica sets
```
mongos> db.shards.find().pretty()
{"_id": "m103-example", "host": "m103-example/192.168.103.100:27011,192.168.103.100:27012,192.168.103.100:27013", "state": 1}
{"_id": "m103-shard-2", "host": "m103-shard-2/192.168.103.100:27014,192.168.103.100:27015,192.168.103.100:27016", "state": 1}
```
In the chunks below, inclusive minimum and exclusive maximum define the chunk
range of shard key values
```
mongos> db.chunks.find().pretty()
...
{
    "_id": "m103.products-salePrice_MinKey",
    "lastmod": Timestamp(2, 0),
    "lastmodEpoch": ObjectId("5ab2cf3e5dd02e195c0c980a"),
    "ns": "m103.products",
    "min": {"salePrice": {"$minKey": 1}},
    "max": {"salePrice": 14.99},
    "shard": "m103-shard-2"
}
{
    "_id": "m103.products-salePrice_14.99",
    "lastmod": Timestamp(2, 1),
    "lastmodEpoch": ObjectId("5ab2cf3e5dd02e195c0c980a"),
    "ns": "m103.products",
    "min": {"salePrice": 14.99},
    "max": {"salePrice": 33.99},
    "shard": "m103-example"
}
...
```
Info about `mongos` processes currently connected to this cluster:
```
mongos> db.mongos.find().pretty()
{
    "_id": "m103:26000",
    "mongoVersion": "3.6.2-rc0",
    "ping": ISODate("2018-03-21T21:47:07.500Z"),
    "up": NumberLong(3892),
    "waiting": true
}
```
Right now, only one mongos is connected.

### Shard Keys
Chunk is a group of documents located on a particular shard. A shard key must
be present in every document of shared collection and every new document
inserted.
- Shared Key Field(s) must be idexed
  - Indexes must exist _first_ before one can select the indexed field for
    a shard key.
- Shard Keys are immutable
  - One cannot change the shard key fields post-sharding
  - One cannot change the values of the shard key fields post-sharding
- Shard Keys are permanent
  - It is impossible to unshard a sharded collection

Shard the `products` collection from the `m103` database over the `sku` field.
```
mongos> sh.status()
...
shards:
{"_id": "m103-shard-2", "host": "m103-shard-1/192.168.103.100:27011,192.168.103.100:27012,192.168.103.100:27013", "state": 1}
{"_id": "m103-shard-2", "host": "m103-shard-2/192.168.103.100:27014,192.168.103.100:27015,192.168.103.100:27016", "state": 1}
...
mongos> use m103
mongos> show collections
mongos> sh.enableSharding("m103")
mongos> db.products.createIndex({"sku": 1})
mongos> sh.shardCollection("m103.products", {"sku": 1})
mongos> sh.status()
...
        shard key: {"sku": 1},
        unique: false,
        balancing: true,
        chunks:
            m103-example-shard1    2
            m103-example-shard2    1
        {"sku": {"$minKey": 1}} -->> {"sku": 23153496} on:  m103-example-shard2 Timestamp(2, 0)
        {"sku": 23153496} -->> {"sku": 28928914} on:  m103-example-shard1 Timestamp(2, 1)
        {"sku": 28928914} -->> {"sku": {"$maxKey": 1}} on:  m103-example-shard1 Timestamp(1, 2)
...
```

### Picking a Goog Shard Key
For a good _write distribution_, a shard key must have:
01. high cordinality, i.e. many possible unique shard key values.
    Cardinality constraines the number of the number of shards in a cluster
    because chunks are defined based on shard key boundaries and a unique value
    can only exist on one chunk. Number of unique values of a shard key is the
    upper limit of the shard count in the a cluster.
02. low frequence, i.e. low repetition of a given unique shard key value.
    High frequence a key would mean many documents go to a specific shard
    whose range contains making that shard a "hot-spot".
03. non-monotonic value change; monotonic value mean a rolling "hot-spot"
    in a cluster

Where possible, shard key shall provide a good _read isolation_, so that most
queries go to a specific shard as opposed to much slower scatter-gather read
pattern.

Testing differnt shard keys in a staging environment first before sharding in
production environment is a good idea.

### Hashed Shard Keys
Which a hashed shard key, `mongos` first hashes the value of shard key and the
hashing result decides which shard to put the document in. MongoDB doesn't store
hashed keys as hashed. The actual data remain untouched. Underlying index
backing the shard key itself is hashed. And MongoDB uses that hashed index to
partition the data in the collection across shards. Hashed shard key provides
even distribution of shard keys on monotonically changing fields like dates but
have their own drawbacks:
- no read isolation: ranged queries of shard key values are more likely to be
  scatter-gather
- no geographically isolation read operations using zoned sharding
- one can't create hashed compound indexes: hashed index must be on a single
  non-array field
- hashed indexes don't support fast soring

Creating a hashed shard key (note creating hashed index as well):
```
mongos> use m103
mongos> show collections
mongos> sh.enableSharding("m103")
mongos> db.products.createIndex({"sku": "hashed"})
mongos> sh.shardCollection("m103.products", {"sku": "hashed"})
mongos> sh.status()
```

### Chunks
```
$ mongos --port 26000 \
  --username m103-admin --password m103-passwd --authenticationDatabase admin
mongos> use config
mongos> show collections
mongos> db.chunks.findOne()
{
    "_id": "config.system.sessions-_id_MinKey",
    "ns": "config.system.sessions",
    "min": {"x": {"$minKey": 1}},
    "max": {"x": {"$maxKey": 1}},
    "shard": "m103-shard1",
    "lastmod": Timestamp(1, 0),
    "lastmodEpoch": ObjectId("5ab3adf60f8c338dc89f7403")
}
```
The above is example of an "initial chunk". It accomodates shard key (`x` is a
shard above) values from "$minKey" (i.e minus infinity) to "$maxKey"
(i.e. plus infinity). Remember that, lower chunk bound is inclusive while
the upper one is exlusive. As time progresses, the cluster with split up the
chunk that initial chunk into several others to make the data distribution more
even across shards. All the documents of a chunk live on a single shard.
By default, MongoDB takes chunk size of 64MB. Chunk size of configurable during
runtime is `1MD <= chunk size <= 1024MB` range.
See how many chunks we currently have:
```
mongos> sh.status()
...
        chunks:
            m103-example-shard1    2
            m103-example-shard2    1
        {"sku": {"$minKey": 1}} -->> {"sku": 23153496} on:  m103-example-shard2 Timestamp(2, 0)
        {"sku": 23153496} -->> {"sku": 28928914} on:  m103-example-shard1 Timestamp(2, 1)
        {"sku": 28928914} -->> {"sku": {"$maxKey": 1}} on:  m103-example-shard1 Timestamp(1, 2)
...

```
Let's reduce chunk size to 2MB and see what happens:
```
mongos> db.settings.save({_id: "chunksize", value: 2})
mongos> sh.status()
<nothing changed>
```
Nothing changed because we haven't done anything to the previous working
configuration. Let's import more data and see what happens:
```
$ mongoimport --port 26000 \
  -u "m103-admin" -p "m103-pass" --authenticationDatabase "admin" \
  --db m103 --collection products /dataset/products.part2.json
$ mongos --port 26000 \
  --username m103-admin --password m103-passwd --authenticationDatabase admin
mongos> sh.status()
...
        chunks:
            m103-example-shard1    43
            m103-example-shard2    8
        too many chunks to print
...
```
After some time passes, the cluster distributes the chunks more evenly:
```
mongos> sh.status()
...
        chunks:
            m103-example-shard1    29
            m103-example-shard2    22
        too many chunks to print
...
```

Let's image some shard key value has high frequency. That may end up in the
situation when say 90% of new documents go to a signgle chunk. That junk may
become a jumbo chunk.

Jumbo chunks:
- Larger than defined chunk size
- Cannot be moved: once marked as jumbo the balancer skips these chunks and
  avoids trying to move them
- In some cases they cannot even be split

Presence of jumbo chunks is a damaging situation. Keep an eye on preventing them.

### Balancing
Balancer process runs of the primary member of config server replica set. The
balancer process checks distribution of chunks across a sharded cluster and
looks for certain migration thresholds. If it detects an inbalance, it starts
a balancer round. The balancer can migrate chunks in parallel but any given
shard can't participate in more than one migration at a time. Number of shards
devides by two and downrounded gives a maximum number of chunks that can be
migrated at a balancer round. Balancer can split chunks as needed.
```
> sh.startBalancer(timeout, interval)
> sh.stopBalancer(timeout, interval)
> sh.setBalancerState(boolean)
```

### Queries in a Sharded Cluster
In a sharded cluster, all queries must be directed to the `mongos`. The first
things the `mongos` does is determinig the list of shards that must receive a
query. If a query predicate includes a shard key, then the `mongos` can
specifically target only those shard that contain the key value. These targeted
queries are very efficient. If a query is very wide in scope, then the `mongos`
has to target every shard in a cluster. These scatter-gather operations can be
slow depending on a number of factors such as the number of shards in the
cluster. Whether we have targeted or scatter-gather query, the `mongos` opens
a cursor against each of the targeted shard. Each cursor executed the query
predicate and retured any data returned by the query for that shard. The
`mongos` merges all the results together to form the total set set of document
that fulfills the query and returns that set of document to the client
application.

When it comes to `sort()`, `limit()` and `skip()`, the `mongos`:
- `sort()`: the `mongos` pushes the sort to each shard and merge-sorts the
  result
- `limit()`: the `mongos` passes the limit to each targeted shard, then
  re-applies the limit to the merged set of results
- `skip()`: the `mongos` performes skipping on the merged set of results

When used in conjunction with a `limit()`, the mongos will pass the limit plus
the value of the `skip()` to the shards to ensure a sufficient number of
documents are returned to the mongos to apply the final `limit()` and `skip()`
successfully.

### Targetet (Isolated) vs Scatter-Gather Queries
The config server replica set keeps a table of a shard-chunk relationships:

| Shard | Data |
|-------|------|
| 1 | minKey -> 10000000 |
| 2 | 10000000 -> 20000000 |
| 3 | 20000000 -> maxKey |

The `mongos` keeps a cached local copy of this metadata table, i.e. each
`mongos` has a map of which shard contains any given shard value. When the
`mongos` receives a query whose predicate includes the shard key, the `mongos`
can look at the table and know exactly which shard to direct that query to.
The `mongos` opens the cursor against only those shards that can satisfy the
query predicate.

When the query predicate does not include the shard key, the `mongos` cannot
cannot derive exaclty which shard satisfy the query. These scatter-gather
queries must necessarily ping and wait for reply of every shard in the cluster,
regardless if they have something to contribute towards the execution of the
query or not. Depending on the number of shards in the cluster, network latency,
etc., these queries can be slow.

Ranges queries on a _hashed_ shard key are almost always scatter-gather because
two adjacent shard key values are likely to be on two completely different
chunks. Single document queries on a hashed shard key can still be targeted
though.

If a sharding is done over a compound key, e.g.
```
{ "sku": 1, "type": 1, "name": 1 }
```
then you can specify each prefix up to the entier shard key and still get a
targeted query:
```
db.products.find( { "sku": ... } )
db.products.find( { "sku": ... , "type": ... } )
db.products.find( { "sku": ... , "type": ... , "name": ... } )
```
But the queries below require scatter-gather:
```
db.products.find( { "type": ... } )
db.products.find( { "name": ... } )
```

See whether or not a query is targeted. Let's see the cluster confiugraion
first.
```
mongos> use m103
mongos> show collections
products
mongos> sh.status()
...
shards:
{"_id": "m103-shard-2", "host": "m103-shard-1/192.168.103.100:27011,192.168.103.100:27012,192.168.103.100:27013", "state": 1}
{"_id": "m103-shard-2", "host": "m103-shard-2/192.168.103.100:27014,192.168.103.100:27015,192.168.103.100:27016", "state": 1}
...
    m103.products
        shard key: {"sku": 1}
        unique: false
        balancing: true
        chunks:
            m103-example-shard1    2
            m103-example-shard2    1
        {"sku": {"$minKey": 1}} -->> {"sku": 23153496} on:  m103-example-shard2 Timestamp(2, 0)
        {"sku": 23153496} -->> {"sku": 28928914} on:  m103-example-shard1 Timestamp(2, 1)
        {"sku": 28928914} -->> {"sku": {"$maxKey": 1}} on:  m103-example-shard1 Timestamp(1, 2)
...
```
We have two shard with two chanks on the first one and one chunk on the second
one.

Use the `explain()` query modifier
```
mongos> db.products.find({"sku" : 1000000749}).explain()
{
    "queryPlanner": {
        "mongosPlannerVersion": 1,
        "winningPlan": {
            "stage": SINGLE_SHARD,
            "shards": [
                {
                    "shardName": "m103-shard1",
                    ...
                    "winningPlan": {
                        "stage": FETCH,
                        "inputStage": {
                            "stage": SHARDING_FILTER,
                            "inputStage": {
                                "stage": IXSCAN,
                                "keyPatter": {"sku": 1},
                                "indexName": "sku_1",
                                ...
                            }
                        }
                    }
                }
            ]
        }
    }
}
```
The `SINGLE_SHARD` means that not was `mongos` to target a subset of shards, it
was able to retrieve the entire result set from a single shard without needing
to merge the results. The `shards` array displays each shard queries and
provides specific plan executed on that shard. The `IXSCAN` means there is an
index scan underneath, because the shard could use the `sku_1` index to
satisfy the query.


If we use the `name` field in the query predicate, we get the following:
```
mongos> db.products.find({"name": "Alpha Bravo"}).explain()
{
    "queryPlanner": {
        "mongosPlannerVersion": 1,
        "winningPlan": {
            "stage": SHARD_MERGE,
            "shards": [
                {
                    "shardName": "m103-shard1",
                    ...
                },
                {
                    "shardName": "m103-shard2",
                    ...
                },
            ]
        }
    }
}

```
For a stage, we now have `SHARD_MERGE`. Furthermore, in the `shards` array, we
now have both `shard1` and `shard2`. This is a scatter-gather query, and
required a merge. The `name` field isn't in our shard key, so this is
necessarily a scatter-gather query.

Both queries were returning the same document. But by specifying `sku` instead
of the `name`, we can get the result more quickly. If we know that the workload
use `name` 90% of the time, we it would have been bettter for use to have
choosen `name` instead of `sku` as the shard key.
