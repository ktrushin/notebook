# M201 MongoDB Performance

## Introduction
### Hardware Considerations and Configurations
RAID 10 is the recommended RAID architecture for MongoDB deployments.

## MongoDB Indexes
### Introduction to Indexes
### How Data is Stored on Disk
The WiredTiger storage engine create an individual file for each collection and
index, the `_mdb_catalog.wt` file contains the catalog of all different
collections and indexes this particular `mongod` contains.
```
$ mongod --dbpath /data/db --fork --logpath /data/db/mongod.log
$ mongosh admin --eval 'db.shutdownServer()'
$ ls /data/db
_mdb_catalog.wt
...
collection-<N>-<some_code>.wt
...
index-<M>-<some_other_code>.wt
...
```
If run with the `--directoryperdb` option, `mongod` creates more hierarchical
file system:
```
$ mongod --dbpath /data/db --fork --logpath /data/db/mongod.log \
  --directoryperdb
$ mongosh hello --eval 'db.a.insert({a: 1}, {writeConcern: {w: 1, j: true}})'
$ mongosh admin --eval 'db.shutdownServer()'
$ ls /data/db/
_mdb_catalog.wt
admin
local
hello
$ ls /data/db/hello
collection-<N>-<some_code>.wt
index-<M>-<some_other_code>.wt
```
where `hello` is the name of the newly created database, and `admin` and `local`
are the databases created by default.

We can even split collectoin and indexes to different directories
```
$ mongod --dbpath /data/db --fork --logpath /data/db/mongod.log \
  --directoryperdb --wiredTigerDirectoryForIndexes
$ mongosh hello --eval 'db.a.insert({a: 1}, {writeConcern: {w: 1, j: true}})'
$ mongosh admin --eval 'db.shutdownServer()'
$ ls /data/db/
_mdb_catalog.wt
admin
local
hello
$ tree /data/db/hello
- collection
  - collection-<N>-<some_code>.wt
- index
  - index-<M>-<some_other_code>.wt
```
The latter can be helpful for parallelalizing I/O operations if the `collection`
and `index` directories are located in different physical disks.

### Single Field Indexes
Import some data and do a find without index. We see that it does full
collection scan (`COLLSCAN`) examining 50474 documents.
```
$ mongoimport -d m201 -c people --drop people.json
$ mongosh m201
> db.people.find({"ssn": "720-38-5636"}).explain("executionStats")
...
  "queryPlanner": {
    "winningPlan": {
      "stage": "COLLSCAN",
    },
    ...
    "executtionStats": {
      ...
      "totalDocsExamined": 50474,
      "totalKeysExamined": 0
      "nReturned": 1,
      ...
    }
  }
```
Create index and an explainable object and run the find on the latter. Now we
see that the index is used (`IXSCAN`) and only one document is examined. Also,
note that only one index key was looked at (`"totalKeysExamined": 1`)
```
> db.people.createIndex({ssn: 1})
> exp = db.people.explain("executionStats")
Explainable(m201.people)
> exp.find({"ssn": "720-38-5636"})
...
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN"
    },
  },
  "executionStats": {
      "totalDocsExamined": 1,
      "totalKeysExamined": 1,
      "nReturned": 1,

  }
```
However, if the query predicate does not use the field on which the index is
done, we aren't able to use index and have to a collection scan
```
> exp.find({last_name: "Acavedo"})
...
  "queryPlanner": {
    "winningPlan": {
      "stage": "COLLSCAN",
    },
    ...
    "executtionStats": {
      ...
      "totalDocsExamined": 50474,
      "totalKeysExamined": 0
      "nReturned": 10,
      ...
    }
  }
```
We can use dot notation when specifying indexes.
```
> db.examples.insertOne({_id: 0, subdoc: {indexedField: "value", otherField: "value"}})
> db.examples.insertOne({_id: 1, subdoc: {indexedField: "wrongValue", otherField: "value"}})
> db.examples.createIndex({"subdoc.indexedField": 1})
> db.examples.explain("executionStats").find({"subdoc.indexedField": "value"})
...
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN"
    },
  },
...
```
It is a bad idea to create an index on the whole subdocument. Instead, create
a compound index with only those fields of the subdocument which you care about.

Find a range of social security numbers
```
> exp.find({ssn: {$gte: "555-00-0000", $lt: "556-00-0000"}})
...
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN"
    },
  },
...
  "executtionStats": {
    ...
    "totalKeysExamined": 49
    "totalDocsExamined": 49,
    "nReturned": 49,
    ...
  }
```
Find a set of social security numbers:
```
> exp.find({ssn: {$in: ["001-29-9184", "177-45-0950", "265-67-9973"]}})
...
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN"
    },
  },
...
...
  "executtionStats": {
    ...
    "totalKeysExamined": 6
    "totalDocsExamined": 3,
    "nReturned": 3,
    ...
  }
```

If multiple fields are specified in the query, we can still use the index:
```
> exp.find({ssn: {$in: ["001-29-9184", "177-45-0950", "265-67-9973"]}, last_name: {$gte: "H"}})
...
  "winningPlan": {
    "stage": "FETCH",
    "filter": {
      "last_name": {"$gte": "H"}
    }
    "inputStage": {
      "stage": "IXSCAN",
      "keyPattern": {"ssn": 1}
    },
  },
...
>
```
By looking at the winning plan, we can see that we are doing index scan on
the social security number to filter down to the three document that match our
query, and then from those three documents we filtering on which of those three
match the last name predicate.

## Understanding Explain

Run `explain` directly
```
> db.people.find({"address.city": "Lake Meaganton"}).explain()
```
or create an explainable object
```
> exp = db.people.explain()
> exp.find({"address.city": "Lake Meaganton"})
> exp.find({"address.city": "Lake Brenda"})
```
In the latter case the actual query is not executed. The `explain()` method
accepts one of the three possible arguments
- "queryPlanner" (default)
- "executionStats"
- "allPlansExecution"

Two last arguments make `explain` to actually execute the query, whilst the
first one does not.

Some examples.
```
> use m201
> exp = db.people.explain()
Explainable(m201.people)
> expRun = db.people.explain("executionStats")
Explainable(m201.people)
> expRunVerbose = db.people.explain("allPlansExecution")
Explainable(m201.people)
>
> expRun.find({last_name: "Johnson", "address.state": "New York"})
{
  "queryPlanner": {
    ...
    "winningPlan": {
      "stage": "COLLSCAN",
    },
    "executioinStats": {
      "totalKeysExamined": 0,
      "totalDocsExamined": 50474,
      "nReturned": 7,
      ...
    }
  }
}
>
> db.people.createIndex({last_name:1})
> expRun.find({last_name: "Johnson", "address.state": "New York"})
{
  "queryPlanner": {
    ...
    "winningPlan": {
      "stage": "FETCH",
      "filter": {"address.state": "New York"},
      "inputStage": {
        "stage": "IXSCAN",
        "keyPattern": {"last_name": 1},
        "indexName": "last_name_1",
      }
    },
    "executioinStats": {
      "totalKeysExamined": 794,
      "totalDocsExamined": 794,
      "nReturned": 7,
      ...
    }
  }
}
```
For a most optimized queries, we want `totalDocsExamined` and
`totalKeysExamined` to be close to `nReturned`, though that is not always
possible.

Let's create another index and see how it affects the same queries.
```
> db.people.createIndex({"address.state": 1, last_name: 1})
> expRun.find({last_name: "Johnson", "address.state": "New York"})
{
  "queryPlanner": {
    ...
    "winningPlan": {
      "stage": "FETCH",
      "filter": {"address.state": "New York"},
      "inputStage": {
        "stage": "IXSCAN",
        "keyPattern": {"address.state": 1, "last_name": 1},
        "indexName": "address.state_1_last_name_1"
      }
    },
    "rejectedPlans": [
      {
        "stage": "FETCH",
        "filter": {"address.state": "New York"},
        "inputStage": {
          "stage": "IXSCAN",
          "keyPattern": {"last_name": 1},
          "indexName": "last_name_1",
        }
      },
    ],
    "executioinStats": {
      "totalKeysExamined": 7,
      "totalDocsExamined": 7,
      "nReturned": 7,
      ...
    }
  }
}
```
From the values of `totalKeysExamined`, `totalDocsExamined` and `nReturned`, we
can conclude we have a better ratio. Execution time is also lower (not shown
in the example output, though).

We can also look at sorts. We also save the result into a variable to simplify
further access
```
> var res = db.people.find({last_name: "Johnson", "address.state": "New York"}).sort({"birthday": 1}).explain("executionStats")
> res.executionStats.executionStages
{
  ...
  "memUsage": 2894,
  "memLimit": 33554432,
  "inputStage": {
    "stage": "SORT_KEY_GENERATOR",
    "nReturned": 7,
    "inputStage": {
      "stage": "FETCH",
      "nReturned": 7,
      "inputStage": {
        "stage": "IXSCAN",
        "nReturned": 7,
        "keyPattern": {"address.state": 1, "last_name": 1},
        "indexName": "address.state_1_last_name_1"
      }
    }
  }
}
```
We are doing index scan first, then fetch, and, finally, sort key generator.
The latter means in-memory sort because we don't have an index to support sorting.
Please note, we use about 2.8KB memory for sorting (see `memUsage`). If the sort
is going to use more than `memLimit` (32MB in our case), server just cancels
that query. Given the average size of a document and the number of documents
being sorted, we can predict if whether the server cancels the query or not.

### Understanding Explain for Sharded Clusters

Setting up a sharded cluster with `mlaunch` from `mtools` (mongo tools?)
```
$ mlauch init --single --sharded 2
mongos> use m201
mongos> sh.enableSharding("m201")
mongos> sh.shardCollection("m201.people", {_id: 1})
```
In another concole:
```
$ mongoimport -d m201 -c people --drop people.json
```
Back to the first console:
```
mongos> db.people.getShardDistribution()
Shard shard01 contains 98% data
Shard shard02 contains 2% data

> db.people.find({last_name: "Johnson", "address.state": "New York"}).explain("executionStats")
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "SHARD_MEGE",
      "shards": [
        {
          "shardName": "shard01",
          "winningPlan": {
            "stage": "SHARDING_FILTER",
            "inpustStage": {
              "stage": "COLLSCAN"
            }
          }
        },
        {
          "shardName": "shard02",
          "winningPlan": {
            "stage": "SHARDING_FILTER",
            "inpustStage": {
              "stage": "COLLSCAN"
            }
          }
        }
      ]
    }
  }
}
```

### Sorting with Indexes
Methods for sorting
- in memory
- using an index

Let's discuss in memory sorting first. Documents are stored on disk in an
unknown order. When we query the server, the documents are going to be returned
in the same order the server find them. When we add sort, the server has to read
the documents from the disk to the RAM. The server performs a sorting algorithm
on documents in RAM. Since the sorting might be an expensive operation, the
server aborts it if 32MB or more memory is used for that.

In an index, the key are ordered according to the field specified during index
creation. The server can take advantage of that to provide the sort. If the
query is using an index scan, the order of the documents returned is guaranteed
to be sorted by the index keys. This means there is no need to perform explicit
sort since the documents are fetch from the server in the sorted order.
The documents are only going to be ordered according to the fields that make up
the index. Query planner considers the indexes that can be helpful to either
the query predicate or to the requested sort.

```
$ mongoimport -d m201 -c people --drop people.json
> use m201
> db.people.find({}, {_id: 0, first_name: 1, last_name: 1, ssn: 1}).sort({ssn: 1})
> var exp = db.people.explain("executionStats")
> exp.find({}, {_id: 0, first_name: 1, last_name: 1, ssn: 1}).sort({ssn: 1})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN",
      }
    },
  "executionStats": {
    "totalDocsExamined": 50747,
    "totalKeysExamined": 50747,
    "nReturned": 50747,
  }
}
```
The server did index scan even though all the documents were requested because
the index wasn't used for filtering documents, but was rather used for sorting.

If we sort on first name, which we don't have an index for
```
> exp.find({}, {_id: 0, first_name: 1, last_name: 1, ssn: 1}).sort({first_name: 1})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "PROJECTION",
      "inputStage": {
        "stage": "SORT",
        "inputStage": {
          "stage": "SORT_KEY_GENERATO",
          "inputStage": {
            "stage": "COLLSCAN",
          }
        }
      }
    }
  },
  "executionStats": {
    "totalDocsExamined": 50747,
    "totalKeysExamined": 0,
    "nReturned": 50747,
  }
}
```
We did a collection scan (`"stage": "COLLSCAN"`), read all the docs in memory
(`"stage": "SORT_KEY_GENERATO"`) and did in memory sort (`"stage": "SORT"`).
Also `"totalKeysExamined": 0` suggests no index was used.


If we sort in descending order by social security number, we are still able to
use the index to support sorting. However, we scan the index backwards. When we
sorting with a single field index, we can always do that.
```
> exp.find({}, {_id: 0, first_name: 1, last_name: 1, ssn: 1}).sort({ssn: -1})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN",
        "direction": "backwards"
      }
    },
  "executionStats": {
    "totalDocsExamined": 50747,
    "totalKeysExamined": 50747,
    "nReturned": 50747,
  }
}
```

Moreover, we can both filter and sort in the same query. For instance we sort
in descending order those documents whose social security number starts with
triple five.
```
> exp.find({ssn: /^555/}, {_id: 0, first_name: 1, last_name: 1, ssn: 1}).sort({ssn: -1})
...
      "inputStage": {
        "stage": "IXSCAN",
        "direction": "backwards"
...
  "executionStats": {
    "totalDocsExamined": 49,
    "totalKeysExamined": 51,
    "nReturned": 49,
    "executionTimeMillis": 0
...
```
We did index scan and this index scan was used both for filtering and sorting
the documents because we only had to look at 49 documents.

What would happened if we built a descending index keys.
```
> db.people.dropIndexes()
> db.people.createIndex({ssn: -1})
> exp.find({ssn: /^555/}, {_id: 0, first_name: 1, last_name: 1, ssn: 1}).sort({ssn: -1})
...
      "inputStage": {
        "stage": "IXSCAN",
        "direction": "forward"
...
  "executionStats": {
    "totalDocsExamined": 49,
    "totalKeysExamined": 51,
    "nReturned": 49,
    "executionTimeMillis": 0
...
```
We're now walking index forward because it is descending index and we sort in
the descending order. Before we were waling index backwards because it was an
ascending index and we sorted in descending order. A walking direction is
not so much important for a single field indexes, but will be more important
for compound indexes.

### Querying on Compound Indexes
A compound index is the index of two or more fields. It is sorted in a
particular order (ascending or descending) on the first field. Among the equal
values of the first field, the second field is also sorted and so on. That makes
it easy to find keys with known N first field values. But getting all the keys
with a particular second (or further) field value requires the full scan of
the collection.

```
$ mongoimport -d m201 -c people --drop people.json
$ mongosh m201
> db.people.find({"last_name": "Frazier", "first_name": "Jasmine"}).explain()
...
    "totalKeysExamined": 0,
    "totalDocsExamined": 50474,
    "nReturned": 1,
    "executionTimeMillis": 24
...
> db.people.createIndex({last_name: 1})
> db.people.find({"last_name": "Frazier", "first_name": "Jasmine"}).explain()
...
    "totalKeysExamined": 31,
    "totalDocsExamined": 31,
    "nReturned": 1,
    "executionTimeMillis": 0
...
> db.people.createIndex({last_name: 1, first_name: 1})
> db.people.find({"last_name": "Frazier", "first_name": "Jasmine"}).explain()
...
    "totalKeysExamined": 1,
    "totalDocsExamined": 1,
    "nReturned": 1,
    "executionTimeMillis": 0
...
> db.people.find({"last_name": "Frazier", "first_name": {$gte: "L"}}).explain()
...
    "totalKeysExamined": 16,
    "totalDocsExamined": 16,
    "nReturned": 16,
    "executionTimeMillis": 0
...
```

Index prefix is a continuous subset of a compound index that starts to the left.
Given a compound index `{item: 1, location: 1, stock: 1}`, the following are
its prefixes: `{item: 1}`, `{item: 1, location: 1}`. While `{stock: 1}`,
`{location: 1, stock: 1}`, `{item: 1, stock: 1}` are not the prefixes of the
index above. Index prefix can be used as a regular index. The query planner
will ignore the other parts of the index.

Example. We already have the compound index `{last_name: 1, first_name: 1}`. An
index prefix for this is `{last_name: 1}`.

```
> db.people.find({"last_name": "Solomon"}).explain()
...
    "totalKeysExamined": 22,
    "totalDocsExamined": 22,
    "nReturned": 22,
    "executionTimeMillis": 0
...
> db.people.find({"first_name": "Sonia"}).explain()
...
    "totalKeysExamined": 0,
    "totalDocsExamined": 50474,
    "nReturned": 8,
    "executionTimeMillis": 25
...
    "stage": "COLLSCAN"
...
```

If we have a compound index, it can service queries for both the compound and
any of its prefixes, but it won't use index when we're not querying on a prefix.
If your application has two queries and one uses fields that are subset of the
other, you should build an index where one query uses the index prefix and the
other uses all fields of the index.

```
> db.people.dropIndex("last_name_1_first_name_1")
> db.people.createIndex({job: 1, employer: 1, last_name: 1, first_name: 1})
> db.people.find({job: "Jewerly designer", employer: "Baldwin-Nichols"}).explain()
...
    "totalKeysExamined": 5,
    "totalDocsExamined": 5,
    "nReturned": 5,
    "executionTimeMillis": 0
...
    "stage": "IXSCAN"
...
> db.people.find({job: "Jewerly designer", employer: "Baldwin-Nichols", last_name: "Cook"}).explain()
...
    "totalKeysExamined": 1,
    "totalDocsExamined": 1,
    "nReturned": 1,
    "executionTimeMillis": 0
...
    "stage": "IXSCAN"
...
> db.people.find({job: "Jewerly designer", employer: "Baldwin-Nichols", first_name: "Sara"}).explain()
...
    "totalKeysExamined": 6,
    "totalDocsExamined": 1,
    "nReturned": 1,
    "executionTimeMillis": 0
...
    "stage": "IXSCAN"
...
```
Note that we were looking on the five unnecessary index keys in the last case.
That's because we were able to use only the `{job: 1, employer: 1}` prefix.

```
> db.people.find({job: "Jewerly designer", first_name: "Sara", last_name: "Cook"}).explain()
...
    "totalKeysExamined": 74,
    "totalDocsExamined": 1,
    "nReturned": 1,
    "executionTimeMillis": 0
...
    "stage": "IXSCAN"
...
```
In the above example, situation is even worse becase only `{job: 1}` prefix
could be used.

### When You Can Sort with Indexes

```
> db.people.find({}).sort({job: 1})
> db.people.find({}).sort({job: 1, employer: 1})
> db.people.getIndexes()
[
  {
    "v": 2,
    "key": {"_id": 1},
    "name": "_id_",
    "ns": "m201.peole"
  },
  {
    "v": 2,
    "key": {"job": 1, "employer": 1, "last_name": 1, "first_name": 1},
    "name": "job_1_employer_1_last_name_1_first_name_1"
    "ns": "m201.peole"
  }
]
>
> var exp = db.people.explain("executionStats")
> exp.find({}).sort({job: 1, employer: 1, last_name: 1})
...
    "stage": "IXSCAN",
    "keyPattern": {
      "job": 1,
      "employer": 1,
      "last_name": 1,
      "first_name": 1
    },
    "indexName": "job_1_employer_1_last_name_1_first_name_1"
...
>
>
> exp.find({}).sort({job: 1, employer: 1})
...
    "stage": "IXSCAN",
    "keyPattern": {
      "job": 1,
      "employer": 1,
      "last_name": 1,
      "first_name": 1
    },
    "indexName": "job_1_employer_1_last_name_1_first_name_1"
...
```
Since the index prefix was used for sorting, MongoDB is still able to use the
compound index we built before.

```
> exp.find({}).sort({employer: 1, job: 1})
...
    "stage": "SORT",
    "inputStage": {
      "stage": "SORT_KEY_GENERATION",
      "inputStage": {
        "stage": "COLLSCAN"
      }
    }
...
```
Since `{employer: 1, job: 1}` is not an index prefix, we have to do the full
collection scan followed by an in-memory sort.

If an index prefix is used for sorting, it does not matter what the query
predicate is:
```
> exp.find({email: "jenniferfreeman@hotmail.com"}).sort({job: 1})
...
    "stage": "IXSCAN",
    "keyPattern": {
      "job": 1,
      "employer": 1,
      "last_name": 1,
      "first_name": 1
    },
    "indexName": "job_1_employer_1_last_name_1_first_name_1"
...
    "totalKeysExamined": 50474,
    "totalDocsExamined": 50474,
    "nReturned": 1,
    "executionTimeMillis": 92
...
```
Even though we're only returning one document, we still have to look at 50K
documents because the index scan was used for sorting, not for filtering.

But the index can be used to both filter and sort documents if the query
includes equality conditions on all the prefix keys that precede the sort keys
```
> exp.find({job: "Graphic designer", employer": "Wilson Ltd"}).sort({last_name: 1})
...
    "stage": "IXSCAN",
    "keyPattern": {
      "job": 1,
      "employer": 1,
      "last_name": 1,
      "first_name": 1
    },
    "indexName": "job_1_employer_1_last_name_1_first_name_1"
...
    "totalKeysExamined": 2,
    "totalDocsExamined": 2,
    "nReturned": 2,
    "executionTimeMillis": 0
...
```
This was a fast query because we were able to use out compound index for both
filtering and sorting.

If we slightly modify the query so that MongoDB is not able to use the index for
sorting.
```
> exp.find({job: "Graphic designer"}).sort({last_name: 1})
...
    "stage": "SORT",
    "inputStage": {
      "stage": "SORT_KEY_GENERATION",
      "inputStage": {
        "stage": "IXSCAN",
        "indexName": "job_1_employer_1_last_name_1_first_name_1"
      }
    }
...
    "totalKeysExamined": 99,
    "totalDocsExamined": 99,
    "nReturned": 99,
    "executionTimeMillis": 0
...
```
Since `{job: 1}` is still an index prefix, we are able to use the index for
filtering. However, `{job: 1, last_name: 1}` is not an index prefix, we are no
longer able to use the index for *both* filtering and _sorting_. The `IXSCAN`
stage means we were able to use the index for filtering. However, the
`SORT_KEY_GENERATION` and `SORT` stages mean we had to do an in-memory sort on
the filtered documents.

In the single key index sorting paragraph, we saw that we were able to walk our
index backwards by inverting the key in our sort predicate.
```
> db.coll.createIndex({a: 1, b: -1, c: 1})
```
The following sort predicate will wall the index forward:
```
> db.coll.fin({}).sort({a: 1, b: -1, c: 1})
```
In order to walk the index backwards all we need to do is invert each key.
```
> db.coll.fin({}).sort({a: -1, b: 1, c: -1})
```
All the following sort queries would use the index for sorting. The first two
would work the index forward because they're index prefixes. The last two
would work the index backwards because they're the inverse of these prefixes.
```
> db.coll.fin({}).sort({a: 1})
> db.coll.fin({}).sort({a: 1, b: -1})
> db.coll.fin({}).sort({a: -1})
> db.coll.fin({}).sort({a: -1, b: 1})
```
Example with the `people` collection:
```
> exp.find({}).sort({job: -1, employer: -1})
...
    "stage": "IXSCAN",
    "indexName": "job_1_employer_1_last_name_1_first_name_1",
    "direction": "backward",
...
    "totalKeysExamined": 99,
    "totalDocsExamined": 99,
    "nReturned": 99,
    "executionTimeMillis": 0
...

```
Since `{job: -1, employer: -1}` is an inverted index prefix, we are:
- able to use index for sorting
- walk index backwards

If we change of on the keys, we have to do a collection scan followed by an
in-memory sort:
```
> exp.find({}).sort({job: -1, employer: 1})
...
    "stage": "SORT",
    "inputStage": {
      "stage": "SORT_KEY_GENERATION",
      "inputStage": {
        "stage": "COLLSCAN",
        "direction": "forward"
      }
    }
```

### Multikey Indexes
Multikey index is an index on the field of an array. For each entry in the array,
the server creates a separate index key. For the document
```
{
  _id: <some_id>,
  productName: "MongoDB Long Sleeve T-Shirt",
  categories: ["T-Shirts", "Clothing", "Apparel"],
  stock: [
    {size: "S", color: "red" , quantity: 25},
    {size: "S", color: "blue", quantity: 10},
    {size: "M", color: "blue", quantity: 50}
  ]
}
```
the command
```
$ db.products.createIndex({categories: 1})
```
creates three index key: for "T-Shirts", for "Clothing", and for "Apparel". With
multikey indexes, we can not only index on scalar values, but we can also index
on nested documents. We might want to create an index on the `quantity` field
of our `stock` sub-documents so that we can sort all these documents by quantity:
```
> db.products.createIndex({"stock.quantity": 1})
```
In this case the server will create three index key, one for each of the
sub-documents. For each index document, we can have at most one index field
whose value is an array. In our case we can create the index on product name and
stock quantity
```
> db.products.createIndex({productName: 1, "stock.quantity": 1})
```
but we can _not_ create the index on categories and stock quantity.

Be careful when creating a multikey index and watch the size of the array.
Otherwise, the index will grow to too large size and can have a problem with
fitting in the memory.

Multikey indexes don't support covered queries.

```
> use m201
> db.products.insert({
  productName: "MongoDB Long Sleeve T-Shirt",
  categories: ["T-Shirts", "Clothing", "Apparel"],
  stock: {size: "L", color: "green" , quantity: 100}
})
> db.product.find({}).pretty()
{
  _id: ObjectId("58a5a4bde1d31df5bfd4d2ef"),
  productName: "MongoDB Long Sleeve T-Shirt",
  categories: ["T-Shirts", "Clothing", "Apparel"],
  stock: {size: "L", color: "green" , quantity: 100}
}
> db.products.createIndex({"stock.quantity": 1})
> var exp = db.products.explain()
> exp.find({"stock.quantity": 10})
{
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN",
      "indexName": "stock.quantity_1",
      "isMultiKey": false
    }
  }
}
>
> db.products.insert({
  productName: "MongoDB Long Sleeve T-Shirt",
  categories: ["T-Shirts", "Clothing", "Apparel"],
  stock: [
    {size: "S", color: "red" , quantity: 25},
    {size: "S", color: "blue", quantity: 10},
    {size: "M", color: "blue", quantity: 50}
  ]
})
> exp.find({"stock.quantity": 10})
{
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN",
      "indexName": "stock.quantity_1",
      "isMultiKey": true
    }
  }
}
```
MongoDB recognizes that the index is multikey when a document is inserted where
that field is an array.
Moreover, if we try to create an index where both fields are arrays, it fails:
```
> db.products.createIndex({categories: 1, "stock.quantity": 1})
{
  ok: 0,
  errmsg: "cannot index parallel arrays [stock] [categories]"
}
```
However, we can still create compund multikey index using product name and stock
quantity because the stock field is only an array.
```
> db.products.createIndex({productName: 1, "stock.quantity": 1})
{
  ok: 1
}
```
It is also file to insert the following document where product name is an array
but stock is not. We should point out, however, that this is not a particularly
good schema to use in the production :)
```
> db.products.insert({
  productName: [
    "MongoDB Long Sleeve T-Shirt",
    "MongoDB Long Sleeve Shirt",
  ]
  categories: ["T-Shirts", "Clothing", "Apparel"],
  stock: {size: "L", color: "green" , quantity: 100}
})
WriteResult({"nInserted": 1})
```
However, if both product name and stock are arrays then we'll get an error:
```
> db.products.insert({
  productName: [
    "MongoDB Long Sleeve T-Shirt",
    "MongoDB Long Sleeve Shirt",
  ]
  categories: ["T-Shirts", "Clothing", "Apparel"],
  stock: [
    {size: "S", color: "red" , quantity: 25},
    {size: "S", color: "blue", quantity: 10},
    {size: "M", color: "blue", quantity: 50}
  ]
})
WriteResult({
  "nInserted": 0,
  "writeError": {
    "code": 171,
    "errmsg": "cannot index parallel arrays [stock] [productName]"
  }
})
```

### Partial Indexes
Sometimes it makes sense to index only a portion (part) of the documents in a
collection. When we index on a subset of our documents, we can have lower
storage requirement and reduce the performance cost of creating and maintaining
indexes.

Consider the collection of documents with restaurant information, e.g.:
```
{
  "_id": <some_id>,
  "name": "Han Dynasty",
  "cuisine": "Sichuan",
  "stars": 4.4,
  "address": {
    "street": "90 3rd Ave",
    "city": "New York",
    "state": "NY",
    "zipcode": "10003"
  }
}
```
Maybe there are lots of queries for finding a particular cuisine in a particular
city, but of all these queries that the server receives, 90% of them are for
restaurants with 3.5 and above stars. Instead of creating a compound index on
city and cuisine or city, cuisine and stars
```
> db.restaurants.createIndex({"address.city": 1, cuisine: 1})
> db.restaurants.createIndex({"address.city": 1, cuisine: 1, stars: 1})
```
we can create a partial index where we index on city and cuisine only if the
restaurant has 3.5 or more stars:
```
> db.restaurants.createIndex(
  {"address.city": 1, cuisine: 1},
  {partialFilterExpression: {stars: {$gte: 3.5}}})
```
We effectively reducing the number of index keys that we need to store, and
therefore reducing our space requirements for our index. This can be useful if
the index has grown too large to fit into memory. Partial indexes can also be
useful with multikey indexes. With multikey indexes, keys are created for each
array entry. If our documents have particularly large arrays, the server will be
creating lots of index keys. This could cause issues with fitting the index into
memory. We can mitigate these kinds of issues by creating a partial index.

Sparse indexes are a special keys of partial indexes. With a sparse index, we
only index where the field exists that we're indexing on, rather than creating
an index key with a null value. We can achieve the same effect by creating a
partial index where the filter expression checks for the existence of the field
we're indexing on:
```
> db.restaurants.createIndex({stars: 1}, {sparse: true})
> db.restaurants.createIndex(
  {stars: 1},
  {partialFilterExpression: {stars: {$exists: true}}})
```
In general, partial indexes are much more expressive than the sparse indexes
because `partialFilterExpression` support virtually any predicate. For instance,
```
> db.restaurants.createIndex(
  {stars: 1},
  {partialFilterExpression: {cuisine: {$exists: true}}})
```
Note we check for `cuisine` existence.


```
> use m201
> db.restaurants.insert({
  "name": "Han Dynasty",
  "cuisine": "Sichuan",
  "stars": 4.4,
  "address": {
    "street": "90 3rd Ave",
    "city": "New York",
    "state": "NY",
    "zipcode": "10003"
  }
})
> db.restaurants.find({"address.city": "New York", "cuisine": "Sichuan"})
{
  "_id": ObjectId("<some_id>"),
  "name": "Han Dynasty",
  "cuisine": "Sichuan",
  "stars": 4.4,
  "address": {
    "street": "90 3rd Ave",
    "city": "New York",
    "state": "NY",
    "zipcode": "10003"
  }
}
> var exp = db.restaurants.explain()
> exp.find({"address.city": "New York", "cuisine": "Sichuan"})
{
  "winningPlan": {
    "stage": "COLLSCAN"
  }
}
> db.restaurants.createIndex(
  {"address.city": 1, "cuisine": 1},
  {partialFilterExpression: {stars: {$gte: 3.5}}})
> exp.find({"address.city": "New York", "cuisine": "Sichuan"})
{
  "winningPlan": {
    "stage": "COLLSCAN",
  }
}
```
In the last example, we see that the collection scan was used rather than index
scan. In order to use a partial index, the query must be guaranteed to match a
subset of the documents, specified by the filter expression. This is because the
server could miss results in the case where matching documents are not indexed.
In order to trigger an index scan, we need to include the stars predicate in the
query that that matches our filter expression. This property will hold
regardless of which documents happen to be in the collection.
```
> exp.find({"address.city": "New York", "cuisine": "Sichuan", stars: {$gte: 4.0}})
{
  "winningPlan": {
    "stage": "FETCH",
    "inputStage": {
      "stage": "IXSCAN",
    }
  }
}
```

While creating a partial index, We cannot specify both the
`partialFilterExpression` and and the `sparse` option. Index on `_id` cannot be
a partial index. Neither can a shard key index.
