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
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "COLLSCAN",
    },
  },
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
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN"
      },
    },
  },
  "executionStats": {
      "totalDocsExamined": 1,
      "totalKeysExamined": 1,
      "nReturned": 1,

  }
}
```
However, if the query predicate does not use the field on which the index is
done, we aren't able to use index and have to a collection scan
```
> exp.find({last_name: "Acavedo"})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "COLLSCAN",
    }
  },
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
    }
  },
...
```
It is a bad idea to create an index on the whole subdocument. Instead, create
a compound index with only those fields of the subdocument which you care about.

Find a range of social security numbers
```
> exp.find({ssn: {$gte: "555-00-0000", $lt: "556-00-0000"}})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN"
      }
    }
  },
  "executtionStats": {
    ...
    "totalKeysExamined": 49
    "totalDocsExamined": 49,
    "nReturned": 49,
    ...
  }
}
```
Find a set of social security numbers:
```
> exp.find({ssn: {$in: ["001-29-9184", "177-45-0950", "265-67-9973"]}})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN"
      }
    }
  },
  "executtionStats": {
    ...
    "totalKeysExamined": 6
    "totalDocsExamined": 3,
    "nReturned": 3,
    ...
  }
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
    }
  },
  "executioinStats": {
    "totalKeysExamined": 0,
    "totalDocsExamined": 50474,
    "nReturned": 7,
    ...
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
    }
  },
  "executioinStats": {
    "totalKeysExamined": 794,
    "totalDocsExamined": 794,
    "nReturned": 7,
    ...
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
      }
    ]
  },
  "executioinStats": {
    "totalKeysExamined": 7,
    "totalDocsExamined": 7,
    "nReturned": 7,
    ...
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
in the same order the server finds them. When we add sort, the server has to read
the documents from the disk to the RAM. The server performs a sorting algorithm
on documents in RAM. Since the sorting might be an expensive operation, the
server aborts it if 32MB or more memory is used for that.

In an index, the key are ordered according to the field specified during index
creation. The server can take advantage of that to provide the sort. If the
query is using an index scan, the order of the documents returned is guaranteed
to be sorted by the index keys. This means there is no need to perform explicit
sort since the documents are fetched from the server in the sorted order.
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
the descending order. Before we were walking index backwards because it was an
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
This was a fast query because we were able to use our compound index for both
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

### Text Indexes
Oftentime, we store text in our docuemnts
```
{
  _id: ObjectId(<some_id>),
  productName: "MongoDB Long Sleeve T-Shirt",
  category: "Clothing"
}
```
And for certain usecases, it can be useful to search for documents based on the
word that are part of those text fields. Though it is possible to use either
the exact match or regex to search for the docuemnt:
```
> db.products.find({productName: "MongoDB Long Sleeve T-Shirt"})
> db.products.find({productName: /T-Shirt/})
```
Both approaches has their own disadvantages. For the first one, a user is
unlikely to know the exact product name. The second one implies a performance
penalty. Text indexes are for rescue. We pass a special `"text"` keyword to
create a text index.
```
> db.products.createIndex({productName: "text"})
```
Now we can leverage MongoDB's full text search capabilities, while avoiding
collection scans
```
> db.products.find({$text: {$search: "t-shirt"}})
```
Under the hood, this works very similarly to multi-key indexes. The server
processes the text field and creates an index key for every unique word in the
string. In the case of our example document, MongoDB would create five index keys:
- `mongodb`
- `long`
- `sleeve`
- `t`
- `shirt`
That's because Unicode considers both spaces and hyphens as text delimiters.
Each of the tokens are also lowercase because, by default, text indexes are case
insensitive.

With regards to performance, like multi-key indexes, we want to be aware that
the bigger our text fields are, the more index keys per document we'll be
producing with the following implications:
- more keys to examine
- increased index size (does the index fit into RAM?)
- increased time to build the index
- decreased write performance

One strategy for reducing the number of index keys that need to be examined
would be to create a compound text index
```
> db.products.createIndex({category: 1, productName: "text"})
> db.products.find({
  category: "Clothing",
  $text: {$search: "t-shirt"}
})
```
This allows us to limit the number of text keys that need to be inspected by
limiting on the clothing category. We only need to examine index keys that fit
the clothing category rather than looking all index keys.

Consider the example below
```
$ mongosh m201
> db.textExample.insertOne({"statement": "MongoDB is the best"})
> db.textExample.insertOne({"statement": "MongoDB is the worst"})
> db.textExample.createIndex({"statement": "text"})
> db.textExample.find({$text: {$search: "MongoDB best"}})
{_id: <id_0>, "statement": "MongoDB is the worst"}
{_id: <id_1>, "statement": "MongoDB is the best"}
```
Since text queries logically "or" each delimeted word, searching for
"MongoDB best" means searching for any documents that include "MongDB" or any
document that include the word "best". To address the above issue, we can
project the special textScore value to our returned results.
```
> db.textExample.find({$text: {$search: "MongoDB best"}}, {score: {$meta: "textScore"}})
{_id: <id_0>, "statement": "MongoDB is the worst", score: 0.75}
{_id: <id_1>, "statement": "MongoDB is the best", score: 1.5}
```
The `$text` operator assigns a score to each document based on the relevance of
that document for a given search query. We can sort by the same projected field:
```
> db.textExample
  .find({$text: {$search: "MongoDB best"}}, {score: {$meta: "textScore"}})
  .sort({score: {$meta: "textScore"}})
{_id: <id_1>, "statement": "MongoDB is the best", score: 1.5}
{_id: <id_0>, "statement": "MongoDB is the worst", score: 0.75}
```

### Collations
Collations allows users to specify language-specific rules for string
comparisons. A collation is defined in MongoDB by the follwoing options:
```
{
  locale: <string>,
  caseLevel: <boolean>,
  caseFirst: <string>,
  strength: <int>,
  numericOrdering: <boolean>,
  alternate: <string>,
  maxVariable: <string>,
  backward: <boolean>
}
```
`locale` determines the ICU supported locale.

Collations can be defined in several different levels. We can define a collation
for a collection, which means that all queries and indexes created in such
collection will be using that particular collation.
```
> use m201
> db.createCollection("foreign_text", {collation: {locale: "pt"}})
> db.foreign_text.insert({"name": "Maximo", "text": "Bom dia minha gente!"})
> db.foreign_text.find({_id: {$exists: 1}}).explain()
{
  "queryPlanner": {
    "collation": {
      "locale": "pt"
    },
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN",
        "indexName": "_id_",
        "collation": {
          "locale": "pt"
        }
      }
    }
  }
}
```
We can use collations for specific requests like queries and aggregations, for
example, where we are defining a different collation that the one used and
defined for the particular collection that supports those find requests or
aggregates
```
> db.foreign_text.find({_id: {$exists: 1}}).collation({locale: "it"})
{_id: <some_id>, "name": "Maximo", "text": "Bom dia minha gente!"}
> db.foreign_text.aggregate([{$match: {_id: {$exists: 1}}}], {collation: {locale: "es"}})
{_id: <some_id>, "name": "Maximo", "text": "Bom dia minha gente!"}
```
We can even specify different collations for our indexes. This way we can create
an index on name that overrides the default collation or any collection level
defined collations.
```
> db.foreing_text.createIndex({name: 1}, {collation: {locale: "it"}})
```
To enable the use of the index on a particular field on a query that uses the
exaclty that field, the query must match the collation of the index. In the
first query below, we use a collection scan and the collation to satisfy the
query is the underlying collation of our collection. In the second query, we
have an index scan since the query collation matches the index collation.
```
> db.foreing_text.find({name: "Maximo"}).explain()
{
  "queryPlanner": {
    "collation": {
      "locale": "pt"
    },
    "winningPlan": {
      "stage": "COLLSCAN"
    }
  }
}
> db.foreing_text.find({name: "Maximo"}).collation({locale: "it"}).explain()
{
  "queryPlanner": {
    "collation": {
      "locale": "it"
    },
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN",
        "indexName": "name_1",
        "collation": {
          "locale": "it"
        },

      }
    }
  }
}
```

Being able to correctly march match and sort text space on a given local is
mandatory for many use cases. Collations allow that correctness. Collations
offer a marginal performance impact and should most definitely be use for
correctness.

Another benefit of introducing collations is the ability to support
case-insensitive indexes. To enable this, we can simply define a collection with
a given local on our collection and setting the `strength` of that collation to
to 1, which offers primary level of comparison, ignoring case and diacritics.
```
> db.createCollection("no_sensitivity", {collation: {locale: "en", strength: 1}})
> db.no_sensitivity.insert({name: "aaaaa"})
> db.no_sensitivity.insert({name: "aAAaa"})
> db.no_sensitivity.insert({name: "AaAaa"})
>
> db.no_sensitivity.find().sort({name: 1})
> db.no_sensitivity.insert({name: "aaaaa"})
> db.no_sensitivity.insert({name: "aAAaa"})
> db.no_sensitivity.insert({name: "AaAaa"})
>
> db.no_sensitivity.find().sort({name: -1})
> db.no_sensitivity.insert({name: "aaaaa"})
> db.no_sensitivity.insert({name: "aAAaa"})
> db.no_sensitivity.insert({name: "AaAaa"})
```
Note that descending sorting produces the same set of results as the ascending
one. This means that this particular collation allows us to have case insensitive
queries, and therefore, the indexes as well.


### Wildcard Indexes
Some workloads have upredictable access patterns. In such cases, each query may
include a combinary of arbitrary large number of different fields. This can make
it very difficult to plan an effective indexing strategy. For these workload,
wee need a way to be able to index on multiple fields without the overhead of
maintaining multiple indexes.

Wildcard indexes give us the ability to index all fields in all documents in a
collection.

MongoDB indexes any scalar values associated with a specified path or parths.
For fields that are documents, MongoDB descends into the document and creates
index keys for each field-value pair it finds. For fields that are arrays,
MongoDB creates an index key for each value of the array. If the array contains
subdocuments, MongoDB, again, will descend through those documents and index all
field value pairs.
```
> db.data.createIndex({'$**': 1})
> db.data.find({"waveMeasurement.waves.height": 0.5}).explain()
{
  "queryyPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": "IXSCAN",
    }
  }
}
> db.data.find({"waveMeasurement.waves.height": 0.5, "waveMeasurement.waves.quality": "9"}).explain()
{
  "queryyPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": "IXSCAN",
    }
  }
}
```
The wildcard index generates generates one virtual single field index at query
execution time. And then the planner assesses them using the standard query
plan score.

While creating an index,uUse wildcard projection option to index only the
subparts withing the `waveMeasurement` field.

```
> db.data.createIndex({'sub_field.$**': 1}, { "wildcardProjection": {"included_field": 1}})
> db.data.createIndex({'sub_field.$**': 1}, { "wildcardProjection": {"exclude_field": 0}})
```
To index all subparts in the `waveMeasurement` field, we would do the following:
```
> db.data.createIndex({'$**': 1}, { "wildcardProjection": {"waveMeasurement": 1}})
```
See the query plan:
```
> db.data.find({"waveMeasurement.seastate.quality": 9}).explain()
{
  "queryyPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": "IXSCAN",
    }
  }
}
```

This command is creating an index on `waveMeasurement.waves` and all subparts:
```
> db.data.createIndex({'waveMeasurement.waves.$**': 1})
> db.data.find({"waveMeasurement.waves.height": 0.5}).explain()
{
  "queryyPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": "IXSCAN",
    }
  }
}
```

Covered queries, that is, queries that can retrieve all the requested data from
the index itself without needing to actually go to the collection. Queries which
use multiple fields can benefit from wildcard indexes. However, wildcard indexes
can only cover queries if the query is on a single field.
The following query will be covered:
```
> db.data.find(
  {"waveMeasurement.waves.height": {$gt: 0.5}},
  {_id: 0, "waveMeasurement.waves.height": 1}
).explain()
```

Syntax for wildcard indexes in short:
- `db.coll.createIndex({'$**': 1})` - index everything
- `db.coll.createIndex({'a.b.$**': 1})` - index `a.b` and all subpath
- `db.coll.createIndex({'$**': 1}, {wildcardProjection: {a: 1}})` - index `a`
  and all subpaths
- `db.coll.createIndex({'$**': 1}, {wildcardProjection: {a: 0}})` - index
  everything but `a`

Wildcard indexes:
- useful for unpredictable workloads
- not a replacement for a traditional indexes
- can index all fields in the collection
- can use dot notation and wildcard projections to index a subset of field in
  each document

### Windcard Index Usecases
Use case examples:
- unpredictable query shapes
- attribuite pattern

#### Arbitrary query shapes
In the following example we have collection of a loan data (`loans`):
```
{
  _id: ObjectId(...),
  date: ISODate(...),
  loan_amount: 10000,
  due_date: ISODate(...),
  interest_rate: NumberDecimal(.043),
  borrower: {
    name: "Matt",
    address: "123 North Street",
    creadit_score: 800,
    age: 18
  }
}
```
Let's say that our department wants to lear more about the types of borrowers
we have. We know that our queries will be run agains the `borrower` subdocuemnt
but we don't know which field of the `borrower` subdocument is going to be the
most important one for us because we've just started exploring the data.
So to enable this sort of open-ended data explaration, we can create a wildcard
index on every field in the `borrower` subdocument
```
> db.loans.createIndex({"borrower.$**": 1})
```
A query on any field in the wildcard will be supported by at least a single
field index.
```
> db.loans.find({"borrower.age": {$gt: 22, $lt: 27}})
```

#### Attribuite pattern (streams.k, streams.v)
The attributes `streams_apple`, `streams_spotify`, `streams_tidal` at the
document level:
```
{
  _id: ObjectId(...),
  title: "Despacito",
  streams_apple: 12784,
  streams_spotify: 18988,
  streams_tidal: 6013
}
```
The same attribuites grouped in an array:
```
{
  _id: ObjectId(...),
  title: "Despacito",
  streams: [
    {"k": "streams_apple", v: 12784},
    {"k": "streams_spotify", v: 18988},
    {"k": "streams_tidal", v: 6013}
  ]
}
```
The attribuite pattern is a data modeling strategy that we can use to index and
query across an arbitrary number of attribuites. In this example, the
attribuites is the number of stream that a song received on different streaming
platforms. We've taken all the top-level fields and put them all in
sub-documents in the same array. This way, we don't need to query accross these
different fields. We can just query on `streams.k` or `streams.v`. We could
create a compound index on on `streams.k` and `streams.v`, and all new
sub-documents in the `streams` array that contain a `k` or a `v` will result in
a new index key being created. But if we use a wildcard index on the streams
field (`streams.$**`), then we can use an object here instead of an array of
sub-documents:
```
{
  _id: ObjectId(...),
  title: "Despacito",
  streams: {    streams_apple: 12784,
    streams_spotify: 18988,
    streams_tidal: 6013
  }
}
```
And we can assume that every field in this sub-document will-be indexed.
```
> db.songs.createIndex({"streams.$**": 1})
> db.songs.find({"streams.streams_apple": {$gt: 10000}})
```
In this example, we didn't need to use an array of subdocuments for these
key-value pairs and give them all a particular name like `k` and `v`. We just
create and index on all the sub-pads in the `stream` sub-document, and then we
can query on those sub-fields knowing that they'll be supported by an index.

## Index Operations
### Building Indexes
Foreground index build blocks the intire database for the duration of index
build.
```
> db.collection.createIndex({title: 1})
```
Background index build uses an incremental approach that is slower than the
foreground index build but it doesn't block the database. Background index build
preriodically blocks the database but will yield incoming read and write
operations, releasing resources to attend to incoming requests. If the index is
larger than the available RAM, then the incremental approach can take much
longer than a foreground index build. Also backround index build produces a less
efficient datastructure than the foreground build does resulting in less optimal
index traversal operations.
```
> db.collection.createIndex({title: 1}, {background: true})
```

Hybrid index build (available since MongoDB version 4.2) replaces both
the foreground and the background mechanisms. Hybrid index build has performance
of the foreground index build and non-locking properties of background index
build meaning that all database operations can proceed uninhibited for the
duration of the build. This is now only way to build an index in MongoDB.

### Query Plans
When a query comes into the database, a query plan is formed, which is a series
of stages that are fed one into another. For a query below,
```
> db.restaurants.find({"address.zipcode": {"$gt": 5000}, cuisine: "Sushi"}).sort(stars: -1)
```
given an index on zipcode and cuisine index, we expect the query plan to look
like this:
```mermaid
flowcharT LR
  IXSCAN --> FETCH --> SORT
```
Since we have an index on zipcode and cuisine, we're able to fetch the record
IDs (please see the `IXSCAN` stage) of the documents that meet the query
predicate. From there, those record IDs are passed up to the `FETCH` stage. This
is where the storage engine is going to convert the record IDs into documents.
And then those documents are passed up to the `SORT` stage, where an in-memory
sort will be performened on them. This is the only reasonable query plan for
this query on this index.

But for a given query, we can have many different query plans based on what
indexes are available. If we have an index on cuisine and stars, that could
prevent an in-memory sort, and we'd have a query plans like:
```mermaid
flowcharT LR
  IXSCAN --> FETCH
```
Here we do an index scan where we fetch the record IDs of the documents in
sorted order. We then pass them to the fetch stage where they're converted into
documents and then returned. So the available indexes will determine what
possible query plans we can use to satisfy the query.

When a fresh query
```
> db.restaurants.find({"address.zipcode": {"$gt": 5000}, cuisine: "Sushi"}).sort(stars: -1)
```
comes into the database for the first time, the server is going to look at all
the available indexes on the collection.
```
{_id: 1}
{name: 1, cuisine: 1, stars: 1}
{"address.zipcode": 1, cuisine: 1}
{"address.zipcode": 1, start: 1}
{cuisine: 1, stars: 1}
```
From there, it will indentify which indexes are viable to satisfy the query
(three last ones in our example). We call them candidate indexes. From these
candidate indexes, the query optimizer candidate plans.

MongoDB has emperical query planner, which means there is going to be a trial
period, where each of the candidate plans is executed over a short period of
time. And the planner will then see which plan performed best. "Best" is
implementation defined, e.g. the plan that returned all the results first or the
plan that returned a certain number of document in sorted order fastest. Query
optimizer can even define "best" in different ways depending on the query.
For this run, this is the winning plan. If we were to run `explain` and look
under the `winningPlan` filed, this is the plan it would be talking about.
The other plans would fall under the `rejectedPlans` field.

It wouldn't make much sense to run a trial run for every query that came into
the database. We're going to have a lot of queries that are going to have the
same shape and would benefit from the same query plans. Because if this, MongoDB
caches which plan it should use for a given query shape. Over time, our
collection is going to change and so are indexes. Under different conditions the
plan cache will evict a plan. This can happen when
- the server is restarted
- threshold is reached: the amount of work performed by the first portion of the
  query exceeds the amount of work performed by the winning plan by a factor of
  ten (10)
- an index is rebuilt
- an index created / dropped


### Forcing Indexes with `hint()`
If the query optimizer doesn't choose the index that we would like to be chosen
for a given query, we can use the `hint()` method to override the query
optimizer's selection:
```
> db.people
    .find({name: "John Doe", zipcode: {$gt: "63000"}})
    .hint({name: 1, zipcode:1})
```
In the example above we are forcing MongoDB to use the
`name ascending zip code ascending` index for this particular query. Here, the
index's shape is used to tell `hint` what index to use. Actual index name can
also be used:
```
> db.people
    .find({name: "John Doe", zipcode: {$gt: "63000"}})
    .hint("name_1_zipcode_1")
```
Use `hint` with caution. MongoDB's query optimizer generally does a pretty good
job of selecting the correct index for a given query. The times when it does
fail to select the best index for a given query is generally where there are a
lot of indexes on your collection. And in those cases, it's probably better to
look at index utilization and determine if you have superfluous indexes that
can be removed rather than using the `hint` method.

### Resource Allocation for Indexes
Indexes can reduce the query execution time by a number (or even several
numbers) of magnitude.

Determine total index size (for the whole database) and index size per
collection:
```
> db
londonbikes
> db.stats()
{
  "db": "londonbikes",
  "collections": 5,
  "views": 0,
  "objects": 9322119,
  "avgObjSize": 402.1234,
  "dataSize": 3754869511,
  "storageSize": 1248612352,
  "numExtents": 0,
  "indexes": 6,
  "indexSize": 129892352,
  "ok": 1
}
> db.rides_other.stats()
{
  ...
  "nindexes": 2,
  "totalIndexSize": 129056768,
  "indexSizes": {
    "_id_": 83673088,
    "endstation_name_1": 45383680
  },
  "ok": 1
}
```
Resourcewise, indexes require disk and memory. Disk is generally not an issue.
If there is no disk space for an index file, the index won't be created at all
and it won't be the biggest problem for a DBA :) After the indexes have been
created, the disk space requirement will be a function of the data set size,
i.e. you will run out of disk space for collection data before having issues
with space for the indexes. If you use multiple physical drives and one of them
is dedicated for the indexes, the space on it should be monitored, though.
In the latter case you can still run out of the disk space on the drive for
indexes before the drives for the collection data become full.

Our deployments should be sized in order to accomodate all the indexes in RAM.
Otherwise, a great deal of disk access will be required to traverse the index
file, you will be doing a lot of page-in (into RAM) and page-out (from RAM)
operations.

Capacity of your server:
```
$ free -h
        total    used    free    shared    buffers    cached
Mem:     3.9G    3.7G    177M      996K        24M      1.7G
```
If one starts MongoDB with cache size of 1GB,
```
$ mongod --dbpath data --wiredTigerCacheSizeGB 1
```
then all the indexes will be placed in that cache size of 1GB.


It's useful to know which percentage of the index actually is living in memory.
```
$ mongosh londonbikes
> db.rides_other.stats({indexDetails: true})
<tons_of_information>
...
  "totalIndexSize": 129056768,
  "indexSizes": {
    "_id_": 83673088,
    "endstation_name_1": 45383680,
    "resource_allocation_2": 435634176
  },
  "ok": 1
>
> let stats = db.rides_other.stats({indexDetails: true})
> stats.indexDetails
{
...
  "endstation_name_1": {
    <tons_of_info>
  }
...
}
>
> stats.indexDetails.endstation_name_1.cache
{
  "bytes currently in the cache": 5434,
  "bytes read into cache": 641,
  ...
  "pages read into cache": 1,
  "pages requested from the cache": 0
}
```
One can compare index file size with `bytes currently in the cache` to determine
percentage of the index currently in RAM. We can determine hit and miss page
ratios by analyzing `pages read into cache` and `pages requested from the cache`.
Currently we have zero for the latter quantity, but if we run our query
```
> db.rides_other.find({endstantion_name: "Milroy Walk, South Bank"})
<results>
> it
<results>
> it
<result>
>
> let stats = db.rides_other.stats({indexDetails: true})
> stats.indexDetails.endstation_name_1.cache
{
  "bytes currently in the cache": 71542,
  "bytes read into cache": 25191,
  ...
  "pages read into cache": 3,
  "pages requested from the cache": 2
}
```
Increase in `pages read into cache` and `pages requested from the cache`
suggests page-in and page-out operations have been done, which is better avoided.

There are two edge cases that don't need the full index in RAM. Most of the
queries are to support operational functionality -- they are recurrently getting
information and using the indexes to support operational workload. Any index
that supports such a query should be in RAM because its data will be utilized.
On the other hand, if we have indexes for supporting reporting and BI tool
mechanisms, chances that you need this information to be always allocated in
memory are very small because the recurrency by which these tools operate is not
in the same amount or degree that the operational workload.

Instead of running reporting and BI queries on primary replica set members and
having the indexes created on those primaries, we can have a secondary replica
set member to requests of our BI tools, and therefore having the indexes that
support those reporting and BI queries being created only on designated nodes.

Another situation when full amount of our indexes does not necessarily requires
to be fully allocated in memory is when we have indexes on fields that grow
monotonically, like counters, dates and incremental IDs. If we have monotonically
increasing data chances are that our index will eventually become unbalanced on
the right-hand side of that index data structure (e.g. B-tree). If we only need
to query on the most recent data, then the amount of index that actually needs
to be in RAM is always going to be the right-end side of your index. We only
need to care about how much data (from the recently added data) we are going to
be needing to access all the time. This is typical scenario of IoT kind of use
cases where new data being created in index will be either time-based or
increamental data that always going to grow positively in the right-end side of
our index.

A typical case of the latter is, for example, when you have something like
checkouts, you create an index that supports the queries on dates and the
queries that you operate from the application is looking to the recent dates
and sorting by date descending so you're always getting the latest results on
your query.
```
> db.checkouts.insert({uid: 1992, date: ISODate()})
> db.checkouts.insert({uid: 1254, date: ISODate()})
> db.checkouts.insert({uid: 2232, date: ISODate()})
> db.checkouts.insert({uid: 5232, date: ISODate()})
>
> db.checkouts.createIndex({date: 1})
>
> db.checkouts.find({date: {$gt: ISODate(now() - 3)}}).sort({date: -1})
```
In these situation you might not need to allocate the full extent of your
supporting index.

In summary, when dealing with indexes, we cannot forget that
- these data structures requires resources
- they are part of the database working set
- we need to take them into consideration in our sizing and maintenance practices

### Basic Benchmarking
Types of Performance Benchmarking
- public test suite
- specific or private testing

Low level benchmarking
- file i/o performance
- scheduler performance
- memory allocation and transfer speed
- thread performance
- database server performance
- transaction isolation
- ...

Tools like
- sysbench
- iibench-mongodb

allow you to go very deep into low-level benchmarking kind of tests.

Database server banchmarking:
- data set load
- writes per second
- reads per second
- balanced workloads
- read/write ratio

Tools like
- YCSB
- TPC

are good test base that you can submit a database to. Please don't forget that
many database server benchmarking tools were originally developed for relational
systems. So if you're looking for YCSB, make sure that you look for a variation
that correlates better to MongoDB.

Distributed systems benchmarking, which for MongoDB is a big thing because it is
a distributed database
- linearization
- serialization
- fault tolerance

Tools like
- HiBench
- Jepsen

The latter is even included in the MongoDB's CI tooling.

Benchmarking conditions are also important. Those tools which were written with
relational databases in mind can make assumptions which are not true for the
document databases.

Look at the `POCDriver` tool.

Benchmarking Anti-Patterns
- database swap replace: it might not be the best way to go forward by using
  one-to-one relationship between relational tables and MongoDB collections.
- using `mongosh` to test performance of read and write requests
- using `mongoimport` to test write performance
- local laptop to run tests
- using default MongoDB parameters (e.g. authentication and authorization is not
  typically set up in that case but can affect performance)

Benchmarking Conditions
- hardware
- clients
- load

## CRUD Optimization
### CRUD Optimization
```
> use m201
> let exp = db.restaurants.explain("executionStats")
> exp.find({"address.zipcode": {$gt: 50000}, cuisine: "Sushi"}).sort(stars: -1)
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "SORT",
      "inputStage": {
        "stage": "SORT_KEY_GENERATOR",
        "inputStage": {
          "stage": "COLLSCAN"
        }
      }
    }
  },
  "executionStats": {
    "nReturned": 11611,
    "executionTimeMillis": 386,
    "totalKeyExamined": 0,
    "totalDocsExamined": 1000000
  }
}
> db.restaurants.createIndex({"address.zipcode": 1, cuisine: 1, stars: 1})
> exp.find({"address.zipcode": {$gt: 50000}, cuisine: "Sushi"}).sort(stars: -1)
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "SORT",
      "inputStage": {
        "stage": "SORT_KEY_GENERATOR",
        "inputStage": {
          "stage": "FETCH",
          "inputStage": {
            "stage": "IXSCAN"
          }
        }
      }
    }
  },
  "executionStats": {
    "nReturned": 11611,
    "executionTimeMillis": 276,
    "totalKeyExamined": 95988,
    "totalDocsExamined": 11611
  }
}
```
Even though we've created an index we're still doin an in-memory sort and we're
looking at a bunch of unnecessary keys (95988).
```
> db.restaurants.find({"address.zipcode": 50000}).count()
10
> db.restaurants.find({"address.zipcode": {$gt: 50000}}).count()
499690
```
Zipcode as a range query is not very selective index because we are returning
half of a million. On the other hand, `cuisine` has an equality condition in our
query and so we'd expect it to be pretty selective.
```
> db.restaurants.find({cuisine: "Sushi"}).count()
23303
```
We see 23K documents which is about only 2% of our 1M document collection. So
this is much more selective that the 50% that we would get with zip code.
Knowing selective parts of our query, we can reorder our index to take advantage
of that.
```
> db.restaurants.createIndex({cuisine: 1, "address.zipcode": 1, stars: 1})
> exp.find({"address.zipcode": {$gt: 50000}, cuisine: "Sushi"}).sort(stars: -1)
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "SORT",
      "inputStage": {
        "stage": "SORT_KEY_GENERATOR",
        "inputStage": {
          "stage": "FETCH",
          "inputStage": {
            "stage": "IXSCAN"
          }
        }
      }
    }
  },
  "executionStats": {
    "nReturned": 11611,
    "executionTimeMillis": 90,
    "totalKeyExamined": 11611,
    "totalDocsExamined": 11611
  }
}
```
Our execution stats are way better now. We don't examine unnecessary key and
execution time has also considerably imporoved. We are still doing an in-memory
sort, however. That might be surprising providing our index includes the `stars`
key. We can only use an index for both filtering and sorting if the key in our
query predicate are equality conditions. Since the `zipcode` is a range query,
we're not able to use that index for sorting. So we can swap start and zipcode,
and this will allow us to prevent doing an in-memory sort
```
> db.restaurants.createIndex({cuisine: 1, stars: 1, "address.zipcode": 1})
> exp.find({"address.zipcode": {$gt: 50000}, cuisine: "Sushi"}).sort(stars: -1)
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "FETCH",
      "inputStage": {
        "stage": "IXSCAN"
      }
    }
  },
  "executionStats": {
    "nReturned": 11611,
    "executionTimeMillis": 43,
    "totalKeyExamined": 11663,
    "totalDocsExamined": 11611
  }
}
```
Our winning plan is now an index scan followed by fetch, no more in-memory sort.
The execution time is also way down (to 43 milliseconds). We are looking at a
few more index keys but that's OK by doing this sort with the index we've
actually saved on execution time overall.

This is an example of `Equality, Sort, Range`. Here are our query and the index
to get the most performant execution
```
> db.restaurants.find({"address.zipcode": {$gt: 50000}, cuisine: "Sushi"}).sort(stars: -1)
> db.restaurants.createIndex({cuisine: 1, stars: 1, "address.zipcode": 1})
```
We can use the phrase `"Equality, Sort, Range"` when building indexes to
determine the best way to service our queries. At the beginning of the index,
we should match on equality conditions in the query predicate, followed by sort
conditions, and finally rangle conditions.

### Covered Queries
Covered queries
- very performant
- satisfied entirely by index keys
- 0 documents need to be examined

Queries only the index can be much faster than querying documents outside of the
index because index keys are typically smaller than the documents they catalog
and index keys are typically available in RAM.

Let's discuss how it works. Imagine we have the following query and an index on
the same fields
```
> db.restaurants.find({name: {$gt: L}, cuisine: 'Sushi', stars: {$gte: 4.0}})
> db.restaurants.createIndex({name: 1, cuisine: 1, stars: 1})
```
If we were to add a projection to the query
```
> db.restaurants.find({name: {$gt: L}, cuisine: 'Sushi', stars: {$gte: 4.0}},
                      {_id: 0, name: 1, cuisine: 1, stars: 1})
```
so we are only including the fields that we're indexing on omitting the `_id`
field, then all the information that we expect to get back already exists in the
keys of the index. Because the index contains all the fields required by the
results of the query, MongoDB can both match the query conditions and return the
results only using the index.
```
> use m201
> let exp = db.restaurants.explain("executionStats")
> db.restaurants.createIndex({name: 1, cuisine: 1, stars: 1})
> db.restaurants.find({name: {$gt: L}, cuisine: 'Sushi', stars: {$gte: 4.0}},
                      {_id: 0, name: 1, cuisine: 1, stars: 1})
{"name": "LAuberge Chez Francois", "cuisine": "Sushi", "stars": 4.1}
...
>
```
We can confirm that it is a cover query by looking at the `explain` output
```
> exp.find({name: {$gt: L}, cuisine: 'Sushi', stars: {$gte: 4.0}},
           {_id: 0, name: 1, cuisine: 1, stars: 1})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "PROJECTION",
      "inputState": {
        "stage": "IXSCAN"
      }
    }
  },
  "executionStats": {
    "nReturned": 2870,
    "executionTimeMillis": 10,
    "totalKeysExamined": 2988,
    "totalDocsExamined": 0
  }
}
```
We didn't actually have to examine any documents (`"totalDocsExamined": 0`), to
return the result. It is also a very fast query (`"executionTimeMillis": 10`).
From the `winningPlan` field, we can see that we are immediately doing an index
scan followed by a projection. We completely skip the `FETCH`stage that we
normally see when we turn record IDs in the documents.

Important caveat. If we just turn off the all the fields except `name`,
`cuisine` and `stars` in the projection, the query is _not_ going to be covered
by the index though get the same results.
```
> db.restaurants.find({name: {$gt: L}, cuisine: 'Sushi', stars: {$gte: 4.0}},
                      {_id: 0, address: 0})
{"name": "LAuberge Chez Francois", "cuisine": "Sushi", "stars": 4.1}
...
>
> exp.find({name: {$gt: L}, cuisine: 'Sushi', stars: {$gte: 4.0}},
           {_id: 0, address: 0})
{
  "queryPlanner": {
    "winningPlan": {
      "stage": "PROJECTION",
      "inputState": {
        "stage": "IXSCAN"
      }
    }
  },
  "executionStats": {
    "nReturned": 2870,
    "executionTimeMillis": 10,
    "totalKeysExamined": 2988,
    "totalDocsExamined": 2870
  }
}
```
Now we are examining documents (`"totalDocsExamined": 2870`). And that makes
sense. When we explicitly omit fields, the query planner has no way of telling
what other fields might be present. We might only have the fields that are index
keys, but there also are might be documents that have other additional fields.
Because of this, an index covers a query only when both all fields in the query
are part of the index and all the fields that turned in the result are in the
same index. That generally means that we need to filter out `_id`.

You can't cover a query if
- any of the index fields are arrays
- any of the index fields are embedded documents
- when run against a `mongos` if the index does not contain a shard key

### Regex Performance

Documents in the collection:
```
{"username": "shaw.carran", ...}
{"username": "anthony.rowley", ...}
{"username": "rafferty.rodolph", ...}
{"username": "raymond.coy", ...}
{"username": "kirby.kohlmorgen", ...}
{"username": "kevin.winfred", ...}
...
```
If we have the following query
```
> db.users.find({username: /kirby/})
```
and there isn't an index on `username`, then we need to do a collection scan.
We have to touch every single document in our collection and apply that regular
expression against each of these documents. Like with tranditional equality
conditions, we can improve the performance of this query by creating an index
on the queries field.
```
> db.users.createIndex({username: 1})
```
Now we only need to apply our reguar expression against every index key instead
of against the whole document. While this will increase the performance of the
query, we still need to look at every index key of our index. This somewhat
defeats the purpose of indexes. Indexes are stored as B-trees because of their
ability to reduce the search space to an ordered subset of the entire index. We
can take advantage of this feature of indexes by adding a carret at the
beginning of our regex condition.
```
> db.users.find({username: /^kirby/})
```
The carret means that we only want to return documents where the username begins
with `kirby`. By doing this, we effectively ignoring all the branches of the
B-tree that don't begin with Kirby. And so we're able to dramatically reduce
the number of index key that need to be examined and therefore increase our
overall query performance. This optimization only works if we're matching at the
beginning of the string. The following query
```
> db.users.find({username: /^.irby/})
```
still needs to examine all the keys in the index because every single character
matches the dot `.`: there could be matching index key that starts with `airby`
or `kirby`, or `rirbi`, or `sirby`, etc.

### Aggregation Performance
Two categories of aggregation queries

| "realtime" processing | batch processing |
|---------------------------------|------------------------------|
| - provide data for applications | - provide data for analytics |
| - query performance is more     | - query performance is less  |
|   important                     |   important                  |

"Realtime" is in quotes because you can never have trully realtime processing.
The result of "realtime" query needs to be provided back to the user in a
reasonable amount of time. Batch queries for analytics are typically run on a
periodic basis and their result aren't inspected minutes, hours or even days
later from when that query was actually ran. We focus on "realtime" processing
in this section, though some principles apply to batch processing as well.

Since aggregation is a bit different than a typical find query, determining
index usage is a bit different as well. With an aggragation query, we form a
pipeline of different aggregation operators which transform our data into the
format that we desire.
```
> db.orders.aggregate([
  {$<oeprator>: <predicate>},
  {$<oeprator>: <predicate>},
  ...
])
```
Some of these aggregation operators are able to use indexes and some of them are
not. But more importantly, since data moves through a pipeline from the first
operator to the last, one the server encounters a stage that is not able to use
indexes, all of the following stages will no longer be able to use indexes
either. The query optimizer tries its best to detect when a stage can be forward
so that indexes can be utilized.
In order for use to determine how aggregation queries are executed, we can pass
the `{explain: true}` document as an option to the aggregation method.
```
> db.orders.aggregate([
  {$<oeprator>: <predicate>},
  {$<oeprator>: <predicate>},
  ...
], {explain: true})
```
For the rest of the section, we'll be dealing with hypothetical `orders`
collection with the index on customer ID.
```
> db.orders.createIndex({cust_id: 1})
```
Unsurprisingly, the `$match` operator is able to utilize indexes. This is
especially true if it's at the beginning of a pipeline. It is naturally that
we want to see operators that use indexes at the from of pipelines.
```
> db.orders.aggregate([
  {$match: {cust_id: "287"}},
  ...
])
```

Similarly, we want to put sort stages as close to the front as possible. We want
to make sure that our sort stages come before any kind of transformations so
that we can make sure we can utilize indexes for sorting.
```
> db.orders.aggregate([
  {$match: {cust_id: {$lt: 50}}},
  {$sort: {cust_id: 1}},
  ...
])
```
If you're doing a `limit` and doing a `sort`, you want to make sure that they're
near each other and at the front of the pipeline.
```
> db.orders.aggregate([
  {$match: {cust_id: {$lt: 50}}},
  {$limit: 10},
  {$sort: {cust_id: 1}},
  ...
])
```
When this happens, the server is able to do a top-k sort. This is when the
server is only able to allocate memory for the final number of documents, in
this case, 10. This can happen even without indexes. This is one of the most
highly-performant non-index situations that you can be in. Optimizations like
this are performed by the query optimizer whenever possible. But if there is a
chance that this optimization can change the output results, then the query
engine will not perform this kind of optimization. That's why understanding
these underlying principles is important.

One should also be aware of memory constrains when doing aggregation.
- Results are sublect to 16MB document limit. Aggregation generally output a
  single document and that single document will be susceptible to this limit.
  This limit does not apply to the documents as they flow through the pipeline.
  As you transform documents, they can exceed 16MB limit, but whatever is
  returned will still fall under 16MB limit. The best way to mitigate this issue
  is to use the `$limit` and `$project` to reduce your resulting document size.
- 100MB RAM per stage limit. The absolute best way to mitigate this is to ensure
  your largest stages are able to utilize indexes. That will reduce the memory
  requirement since the indexes are generally much smaller than the documents
  they reference. With sorting, they dramatically reduce memory requirement
  because you don't need allocate extra memory for that sorting. If you still
  exceed 100MB limit, you can allow MongoDB to use the disk
  ```
  > db.orders.aggregate([...], {allowDiskUse: true})
  ```
  That, however, is an absolute last resort measure because by spilling to disk,
  you can see serious performace degration. Since it negatively affects
  performace, `{allowDiskUse: true}` is more often used in batch processing jobs
  than realtime processing. Finally, `{allowDiskUse: true}` doesn't work with
  `$graphLookup`.

## Performance on Clusters
### Performance Considerations in Distributed Systems
Working with distributed systems
- latency
- data is spread across different nodes
- read implications
- write implications

Before sharding
- sharding is an horizontal scaling solution
- have we reached the limits of our vertical scaling?
- you need to understand how you data grows and how your data is accessed
- sharding works by defining key based ranges - our shard key
- it's important to get good shard key

Latency between:
- client application and `mongos`es
- `mongos`es and config servers
- `mongos`es and shard nodes
- within a shard node: each shard node is a replica set with mulitple nodes

It sometimes makes sense to place `mongos` to the same physical servers where
the client application works, so `client_application`<-->`mongos` lantency is
minimized. Also, make sure `mongos`es connected with shard nodes via a fast
network with large bandwidth.

In routed queries, the shard key in the query, therefore, `mongos` routes the
query to a single or small amount of backend shard nodes. On the other hand,
in scatter-gather queries, there is no shard key in the query, all shard node
are therefore asked for data, which can be considerable slower.
When a query contains a `sort`, sorting is done on each shard where the data for
that query is (routed or scatter-gather). Afterwards, final merge-sort is done
on the primary shard of the database. The same set of logic is applied with a
query contains `skip` and/or `limit`. Local skip and limit is performed on each
affected shard, and then primary shard does final merge of the data and
reapplies `skip` and `limit`. Finally, results are sent back to the client
application via `mongos`.

### Increase Write Performance with Sharding
Shard key should be either index field or an index compound of fields that
exists that exists in every document in the collection.
```
> sh.shardCollection('m201.people', {last_name: 1})
```
Data is split in chunks, each of maximum size of 64MB. Each shard can keep more
that one chunk. Chunks will grow across this value, and then they will be split.
We should ensure chunks are evenly distributed across the shards. To achieve
this, there are three key things to keep in mind when designing a shard key:
- cardinality
- frequency
- rate of change

Cardinality is the number of distinct values for a given shard key. We want high
cardinality. The cardinality of a shard key determines the maximum amount of
chunks that can exist in the cluster. If you can't use a field that has higher
cardinality, you can encrease the cardinality of your shard key by creating a
compound shard key. E.g. if majority of the people on our collection lives in
the New York state, then going from shard key on the state
```
> sh.shardCollection('m201.people', {"address.state": 1})
```
to the combination of state and last name
```
> sh.shardCollection('m201.people', {"address.state": 1, last_name: 1})
```
increases the cardinality from ~1 to a much higher number.

With respect to shard key frequence, we also want the even distribution of each
value of a shard key. If certain values of a shard key come more
ofthen then other, we won't get the even load across the cluster effectively
creating one or more `hot shards` in the cluster. The chunk containing the
frequently appearing values would grow larger and larger. Those chunks might
end up with the lower and upper bound of a shard key being the same, which makes
it no longer eligible for splitting. We call this `jumbo chunks`. This recudes
the effectiveness of horizontal scaling because we won't be able to move these
chunks between shards. The issue of uneven frequency can be mitigated if we
create a good compound shard key.
```
> sh.shardCollection('m201.people', {last_name: 1, _id: 1})
```
You want to make sure that the fields at the beginning of your shard key still
have high cardinality. But by compunding the key, we're able to effectively
distribute the frequency of popular values.

As far as rate of change is concerned, i.e. how value of a shard key change over
time. The key here is that we want to avoid monotonically increasing or
decreasing values in our shard key. The classic example is `ObjectId`. Because
of the way it is designed, new `ObjectId`s will always increase in value. Keep
this in mind, if you're using `_id`'s default data type -- `ObjectId` -- as your
shar key. When we have a monotinically increasing shard key, all the writes are
going to the same shard, i.e. the shard that contains the chunk where the upper
bound is the max key. That shard is often referred to as the "last shard". If we
were to have a monotonically decreasing value, then all the writes would be
coming the the shard where the lower bound is set to the minimal key: the "first
shard". It may be OK, however, to have a monotonically increasing value in a
shard key as long as it's not the first fields of a compound shard key:
```
> sh.shardCollection('m201.people', {last_name: 1, _id: 1})
```
Adding a monotonically increasing value to the end of a shard key actually is
a great idea, because it increased the total cardinality of the shard key since
it's guaranteed to always be unique.

When we make *bulk writes* into MongoDB
```
> db.collection.bulkWrite(
  [<operation_1>, <operation_2>, <operation_3>, ...]
  {ordered: <boolean>}
)
```
we have to specify whether we want those writes to be ordered or unordered. With
and ordered bulk write, the server is going to execute these operations one
after another, waiting for the last response to succeed before executing the
next. If an operation fails, we immediately stop the bulk insertion and report
back to the client. With an unordered bulk write, the server can execute all the
operations in parallel.

In a replica set, the ordered bulk write is processed
entirely in one machine -- the primary. While in a shared cluster, each
operation goes to the next consequentive shard, and the client waits additional
time equal to the that shard latency before sending the next operation to the
next shard. As a result, the total time of the ordered bulk write increases
compared to that in case of a replica set. On the other hand, with an unordered
bulk write we can execute all the operations in parallel (each operation goes to
its own shard), maintaining the distributed benefits that we get with a sharded
cluster.

With a bulk write in a sharded cluster, the `mongos` needs to deserialize these
write operations into the corresponding nodes: `mongos` has to send each write
operation to each individual shard.

### Reading from Secondaries
When we read data from MongoDB, there is an assosiated read preference. By
default is set to "primary", meaning all read go to the primary member of a
resplica set.

```
> db.people.find().readPref("primary")
> db.people.find().readPref("primaryPreferred")
> db.people.find().readPref("secondary")
> db.people.find().readPref("secondaryPreferred")
> db.people.find().readPref("nearest")
```
Using `db.people.find().readPref("secondary")` will route the read to one of the
secondaries. Writes, however, can only be routed to the primary node.
The `secondaryPreferred` means the reads are routed to one of the secondaries
unless there aren't any available, in which case reads will be routed to the
primary. The `nearest` means that the read will be routed to the node with the
lowest network latency (the driver determines this member by measuring network
lag from the heartbeat message).

When we read data from a secondary node, there is a possibility that we are
reading stale data. Since the all writes are routed to the primary, when we read
from the primary, we are guaranteed to read the latest copy of data. This is
called strong consistency. Since the data asynchronously replicated to the
secondaries, reading from a secondary can't guarantee that the data is the
latest. This is called eventual consistency. When setting any read preference
than "primary", we need to make sure our application is OK with reading stale
data.

Reading from a secondary is a *good* idea for:
- Analytics. The queries for analytics are generally resource-intensive and long
  running. They have much different memory footprint then the queries assosiated
  with operational workload. We don't want to execute these queries on the
  primary because the reads and writes of out application will be affected.
  This is possible because analytics jobs are OK with reading stale data.
- Local reads in geographically distributes replica sets. E.g. we have two
  application servers, where one is dedicated to the West Coast of the USA,
  and the other is dedicated to the East Cost. One of the three replica set
  members is locaed on one cost, while the remaining two members reside on the
  other. This setup is favorable when applications need to have low latency
  but are OK with reading stale data.

Reading from a secondary is a *bad* idea for:
- Providing extra capacity for reads. Some people have the false notion that if
  the primary is overworked by writes that they can offload their reads to a
  secondary node. This is not the case, because, as writes come into the primary,
  they are replicated to the secondaries. This means that all members of a
  replica set have roughly the same amount of write traffic. On the other hand,
  if the primary is overworked with reads, and you're OK to read stale data,
  you're fine to read from secondaries.
