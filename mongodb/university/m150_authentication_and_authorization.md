# M150 Authenticaion and Authorization

## Database User Authentication
### Creating the First User
To create the initial database users in MongoDB *while authentication is enabled*:
1. connect to MongoDB via localhost (thus using Localhost Exception)
2. create a user administrator with the role `userAdminAnyDatabase`
3. authenticate as the new user administrator
4. create additioanl users as the user administrator

Edit MongoDB configuration to enable authorization. See the last two lines:
```
$ cat /etc/mongod.conf
storage:
  dbPath: /var/lib/mongodb/
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
net:
  bindIp : localhost
  port: 27017
processManagement:
  fork: true
security:
  authorization: enabled
```
Stop a running instance:
```
$ mongosh admin --host localhost:27000 --eval 'db.shutdownServer()'
```
Restart instance with a new config:
```
$ mongod --config /etc/mongod.conf
```
Connect to the `admin` database of a freshly run instance and create the first
user:
```
$ mongosh admin --host localhost:27000
> db.getUsers()
... Error: not authorized on test to execute command ...
> use admin
> db.createUser({
    user: "globalAdminUser",
    pwd: "5xd49$4%0bef#6c&b*d",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
  });
> db.auth( "globalAdminUser", "5xd49$4%0bef#6c&b*d" )
> db.createUser({
    user: "clusterAdminAny",
    pwd: "a*0f7@2c6#b4f%$d6c^c7d",
    roles: [ "clusterAdmin" ]
  });
```

## Role-Based Access Control
### Built-In Roles
The `userAdminAnyDatabase` role is only available from the `admin` database:
```
> use admin
> db.createUser({
    user: "globalAdminUser",
    pwd: "5xd49$4%0bef#6c&b*d",
    roles: [ {
      role: "userAdminAnyDatabase",
      db: "admin"
    } ]
  });
```
while the `userAdmin` role is available from any database:
```
> use admin
> db.createUser({
    user: "inventoryAdminUser",
    pwd: "f46*5$2a3%ac&43f@17b",
    roles: [
      { role: "userAdmin", db: "inventory" }
    ]
  });
```
A user can also be created without any roles and the roles can be
assigned later with the `grantRolesToUser` command:
```
> use admin
> db.createUser({
    user: "inventoryAdminUser",
    pwd: "4lf12$@0af0e4*9#8af",
    roles: [ ]
  });
> db.grantRolesToUser(
    "inventoryAdminUser",
    [ { role: "userAdmin", db: "inventory" } ]
  )
```

### User-Defined Roles
Creating user-defined roles gives fine-grained control to user administrators:
- this is helpful when the built-in roles grant to too many priviliges
- user admins can adhere to the *Principle of Least Privilege*

Principle of Least Privilege: "users should have the least privilege required
for their intended purpose"

Creating a new role grantRevokeRolesAnyDatabase:
```
$ mongo admin --port 27001
> db.auth("globalAdminUser", "5xd49$4%0bef#6c&b*d")
> use admin
> db.createRole({
    role: "grantRevokeRolesAnyDatabase",
    privileges: [{
      resource: { db: "", collection: "" },
      actions: [ "grantRole", "revokeRole", "viewRole" ]
    }],
    roles: []
  })
> db.getRoles()
```

### Updating User Information
Besided the `grantRolesToUser` and `revokeRolesFromUser`, there is the
`updateUser` command:
```
db.updateUser(
  "<username>",
  {
    roles: [
      {role: "<role>", db: "<database>"} | "<role>",
    ],
    pwd: "<new-password>",
    mechanism: [ "<auth-mechanism>" ]
  }
)
```

## Internal Authentication
Internal authentication verifies the identity of one MongoDB intanse to another.
It is important in a replica set because it prevents unauthorized MongoDB
instance from joining the set and then replicating the data. That requires
access to the primary node and login credential for the `clusterAdmin` user.

### Internal Authentication with Keyfiles
Each node of a replica set must have its own copy of a keyfile. The contents
of a key file is basically a very long password and is equal for each replica
set member.
```
$ cat mongo_1.conf
storage:
  dbPath: /var/lib/mongodb/1/
systemLog:
  destination: file
  path: /var/log/mongodb/1/mongod.log
  logAppend: true
net:
  bindIp : localhost
  port: 27001
processManagement:
  fork: true
replication:
  replSetName: m150-replSet
security:
  keyFile: /var/mongodb/pki/node_1/keyfile
```
Using a `keyfile` implicitly enables user authentication and authorization, so
there is no need to mention `authorization: enabled` in the config file.

The configuration for the second and the third member of the replica set differs
from the above one in in the member number which is included in some filepaths
and the port the MongoDB instance listens on.

Start all three replica set members:
```
$ mongod --config mongo_1.conf
$ mongod --config mongo_2.conf
$ mongod --config mongo_3.conf
```
Initiate a replica set and create the first user leveraging the localhost exception:
```
$ mongosh admin --host localhost:27001
> rs.initiate(
  {
    _id: "m150-replSet",
    version: 1,
    members: [
      { _id: 0, host : "localhost:27001" },
      { _id: 1, host : "localhost:27002" },
      { _id: 2, host : "localhost:27003" }
    ]
  }
)
m150-replSet:PRIMARY>
m150-replSet:PRIMARY> use admin
m150-replSet:PRIMARY> db.createUser({
    user: "globalAdminUser",
    pwd: "5xd49$4%0bef#6c&b*d",
    roles: [ {
      role: "userAdminAnyDatabase",
      db: "admin"
    } ]
  });
m150-replSet:PRIMARY>
m150-replSet:PRIMARY> db.auth( "globalAdminUser", "5xd49$4%0bef#6c&b*d" )
1
m150-replSet:PRIMARY>
m150-replSet:PRIMARY> <continue setting-up replica set as usual>
```

### x.509: An Alternative to SCRAM
