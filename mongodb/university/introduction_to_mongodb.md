# Introduction to MongoDB

## Intro to MongoDB
Getting help
```js
> db.help()
```

## MongoDB and the Document Model
Document example:
```
{
  "_id": 1,
  "name": "AC3 Phone",
  "colors" : ["black", "silver"],
  "price" : 200,
  "available" : true
}
```

## Connecting to a MongoDB Database
Connecting to the Atlas claster with mongo shell
```shell
$ mongosh "mongodb+srv://<host>[:port]/<database_name>" --apiVersion 1 --username <username>
Enter password: ****************
Current Mongosh Log ID: 643befa933815b2754d29870
Connecting to:    mongodb+srv://<credentials>@cluster0.esbgc60.mongodb.net/myFirstDatabase?appName=mongosh+1.8.0
Using MongoDB:    6.0.5 (API Version 1)
Using Mongosh:    1.8.0

For mongosh info see: https://docs.mongodb.com/mongodb-shell/


To help improve our products, anonymous usage data is collected and sent to MongoDB periodically (https://www.mongodb.com/legal/privacy-policy).
You can opt-out by running the disableTelemetry() command.

Atlas atlas-12y05s-shard-0 [primary] myFirstDatabase> const greetingArray = ["Hello", "world", "welcome"];

Atlas atlas-12y05s-shard-0 [primary] myFirstDatabase> const loopArray = (array) => array.forEach(el => console.log(el));

Atlas atlas-12y05s-shard-0 [primary] myFirstDatabase> loopArray(greetingArray)
Hello
world
welcome

Atlas atlas-12y05s-shard-0 [primary] myFirstDatabase>
```

```shell
$ atlas clusters connectionStrings describe myAtlasClusterEDU
$ MY_ATLAS_CONNECTION_STRING=$(atlas clusters connectionStrings describe myAtlasClusterEDU | sed "1 d")
$ mongosh -u <username> -p <password> $MY_ATLAS_CONNECTION_STRING
```

Note. The most probable cause of the
`MongoServerSelectionError: connection <monitor> to <IP> closed` is that
the client address is not added to cluster's allow list on Atlas.
Also ensure the connection string contains correct username-password pair to
prevent an authentication failure.

## MongoDB CRUD Operations: Insert and Find Documents

### Lesson 1: Inserting Documents in a MongoDB Collection
```js
> db.grades.insertOne({
  student_id: 654321,
  products: [
    {type: "exam", score: 90},
    {type: "homework", score: 59},
    {type: "quiz", score: 75},
    {type: "homework", score: 88},
  ],
  class_id: 550,
})
> db.grades.insertMany([
  {
    student_id: 546789,
    products: [
      {type: "quiz", score: 50},
      {type: "homework", score: 70},
      {type: "quiz", score: 66},
      {type: "exam", score: 70},
    ],
    class_id: 551,
  },
  {
    student_id: 777777,
    products: [
      {type: "exam", score: 83},
      {type: "quiz", score: 59},
      {type: "quiz", score: 72},
      {type: "quiz", score: 67},
    ],
    class_id: 550,
  },
  {
    student_id: 223344,
    products: [
      {type: "exam", score: 45},
      {type: "homework", score: 39},
      {type: "quiz", score: 40},
      {type: "homework", score: 88},
    ],
    class_id: 551,
  },
])
```


### Lesson 2: Finding Documents in a MongoDB Collection
Switch to the `training` database
```js
> use training
```
See all the documentss in the `zips` collection and go through the very long
output by iterating the cursor with the `it` command
```js
> db.zips.find()
> it
```
Show all the documents with the Arizona state, the long and equivalent short
forms of the same command are presented below:
```js
> db.zips.find({state: {$eq: "AZ"}})
> db.zips.find({state: "AZ"})
```
Find all the documents with Phoenix and Chicago cities
```js
> db.zips.find({city: {$in: ["PHOENIX", "CHICAGO"]}})
```
Find the document by its identifier:
```js
> db.zips.find({_id: ObjectId("5bd761dcae323e45a93ccff4")})
```

### Lesson 3: Finding Documents by Using Comparison Operators
```js
> db.sales.find({"items.price": {$gt: 50})
> db.sales.find({"items.price": {$lt: 50})
> db.sales.find({"customer.age": {$lte: 65})
> db.sales.find({"customer.age": {$gte: 65})
```

### Lesson 4: Querying on Array Elements in MongoDB
The follwoing query returns all the documents where the `products` is either
a scalar string equal to "laptop" to and array with one of the elements equal to
the "laptop" string.
```js
> db.sales.find({products: "laptop"})
```
Retiurn only those documents where the `products` fields is an array with the
"laptop" element:
```js
> db.sales.find({products: {$elemMatch: {$eq: "laptop"}}})
```
The following query (note `$elemMatch`) will return only the docuements where
the `items` array constains the subdocument statisfying all the specified
criteria.
```js
> db.sales.find({
  items: {
    $elemMatch: {name: "laptop", price: {$gt: 800}, quantity: {$gte: 1}},
  }
})
```

### Lesson 5: Finding Documents by Using Logical Operators
Logical `and` operator in its explicit and implicit forms:
```js
> db.<collection>.find({
  $and: [
    {<expression_0>},
    {<expression_1>},
    ...
  ]
})
> db.<collection>.find({{<expression_0>}, {<expression_1>}, ...})
```
Logica `or` operator:
```js
> db.<collection>.find({
  $or: [
    {<expression_0>},
    {<expression_1>},
    ...
  ]
})
```
Example of logical operator combination:
```js
> db.routes.find({
  $and: [
    { $or: [{ dst_airport: "SEA" }, { src_airport: "SEA" }] },
    { $or: [{ "airline.name": "American Airlines" }, { airplane: 320 }] },
  ]
})
```

## MongoDB CRUD Operations: Replace and Delete Documents
### Replacing a Document in MongoDB
```js
> db.<collection>.replaceOne(<fileter>, <replacement>, [<options>])
> db.books.replaceOne(
  {
    _id: ObjectId("6282afeb441a74a98dbbec4e"),
  },
  {
    title: "Data Science Fundamentals for Python and MongoDB",
    isbn: "1484235967",
    publishedDate: new Date("2018-5-10"),
    thumbnailUrl:
      "https://m.media-amazon.com/images/I/71opmUBc2wL._AC_UY218_.jpg",
    authors: ["David Paper"],
    categories: ["Data Science"],
  }
)
```

### Updating Documents by Using updateOne()
```js
> db.<collection>.updateOne(<fileter>, <update>, [<options>])
> db.podcasts.updateOne(
  { title: "The Developer Hub" },
  { $set: { topics: ["databases", "MongoDB"] } },
  { upsert: true }
)
```
Add a single element to the `hosts` array:
```js
> db.podcasts.updateOne(
  { _id: ObjectId("5e8f8f8f8f8f8f8f8f8f8f8") },
  { $push: { hosts: "Nic Raboy" } }
)
```
Add multiple elements to the `diet` array:
```js
> db.birds.updateOne(
  {_id: ObjectId("6268471e613e55b82d7065d7")},
  {$push: {diet: {$each: ["newts", "opossum", "skunks", "squirrels"]}}})
```
The following would have added the whole
`["newts", "opossum", "skunks", "squirrels"]` array as a single element
at the end of the diet array:
```js
> db.birds.updateOne(
  {_id: ObjectId("6268471e613e55b82d7065d7")},
  {$push: {diet: ["newts", "opossum", "skunks", "squirrels"]}})
```

Increment one filed, add another one and insert the document if it doesn't
already exists at once:
```js
> db.birds.updateOne(
  {common_name: 'Robin Redbreast'},
  {$inc: {sightings: 1}, $set: {last_updated: new Date()}},
  {upsert: true})
```

### Using findAndModify(), updateMany(), deleteOne(), deleteMany()
```js
> db.podcasts.findAndModify({
  query: { _id: ObjectId("6261a92dfee1ff300dc80bf1") },
  update: { $inc: { subscribers: 1 } },
  new: true,
})
> db.<collection>.updateMany(<fileter>, <update>, [<options>])
> db.books.updateMany(
  { publishedDate: { $lt: new Date("2019-01-01") } },
  { $set: { status: "LEGACY" } }
)
> db.<collection>.deleteOne(<fileter>, <options>)
> db.<collection>.deleteMany(<fileter>, <options>)
```

## MongoDB CRUD Operations: Modifying Query Results
Sorting and Limiting Query Results in MongoDB
```js
> db.companies
  .find({ category_code: "music" })
  .sort({ number_of_employees: -1, _id: 1 })
  .limit(3)
```
Returning business name and result fields only
```js
> db.inspections.find(
  { sector: "Restaurant - 818" },
  { business_name: 1, result: 1, _id: 0 }
)
```
Return all inspections with result of "Pass" or "Warning" - exclude date and
zip code
```js
> db.inspections.find(
  { result: { $in: ["Pass", "Warning"] } },
  { date: 0, "address.zip": 0 }
)
```
Counting Documents. Count number of trips over 120 minutes by subscribers.
```js
> db.<collection>.countDocument(<query>, <options>)
> db.trips.countDocuments({tripduration: {$gt: 120}, usertype: "Subscriber"})
```

## MongoDB Aggregation
```js
> db.<collection>.aggregate([
  {$stage_name: {<expression>}},
  {$stage_name: {<expression>}}
])
```
The following aggregation pipeline finds the documents with a field named
"state" that matches a value "CA" and then groups those documents by the group
key "$city" and shows the total number of zip codes in the state of California.
```js
> db.zips.aggregate([
  {$match: {state: "CA"}},
  {$group: {_id: "$city", totalZips: {$count : {}}}}
])
```
The following aggregation pipeline sorts the documents in descending order,
so the documents with the greatest pop value appear first,
and limits the output to only the first five documents after sorting.
```js
> db.zips.aggregate([
  {$sort: {pop: -1}},
  {$limit:  5}
])
```
Show only the state, zip, and population field in each document:
```js
> db.zips.aggregate([
  {$project: {state:1, zip:1, population:"$pop", _id:0}},
])
```
Show the "place" for each zip code:
```js
> db.zips.aggregate([
  {$set: {place: {$concat:["$city", ",", "$state"] }}
])
```
Get population extrapolation:
```js
> db.zips.aggregate([
  {$set: {future_population: {$round: {$multiply: [1.0031, '$population']}}}
])
```
Total number of zip coded in the collections:
```js
> db.zips.aggregate([{$count: "total_zips"}])
```

## MongoDB Indexes
### Single Field Index
```js
> db.customers.createIndex({birthdate: 1})
birthdate_1
> db.customers.createIndex({email: 1}, {unique: true})
email_1
> db.customers.getIndexes()
```
Use `explain()` in a collection when running a query to see the Execution plan.
This plan provides the details of the execution stages (`IXSCAN`, `COLLSCAN`,
`FETCH`, `SORT`, etc.).
- The `IXSCAN` stage indicates the query is using an index and what index is
  being selected.
- The `COLLSCAN` stage indicates a collection scan is perform, not using any
  indexes.
- The `FETCH` stage indicates documents are being read from the collection.
- The `SORT` stage indicates documents are being sorted in memory.
```js
> db.customers.explain().find({birthdate: {$gt:ISODate("1995-08-01")}})
> db.customers.explain().find({birthdate: {$gt:ISODate("1995-08-01")}}).
  sort({email:1})
```

### Compound Index
Create a Compound Index
```js
> db.customers.createIndex({active:1, birthdate:-1, name:1})
```
The order of the fields matters when creating the index and the sort order.
It is recommended to list the fields in the following order: Equality, Sort,
and Range.
- Equality: field/s that matches on a single field value in a query
- Sort: field/s that orders the results by in a query
- Range: field/s that the query filter in a range of valid values
The following query includes an equality match on the active field, a sort on
birthday (descending) and name (ascending), and a range query on birthday too.
```js
> db.customers.find({birthdate: {$gte:ISODate("1977-01-01")}, active:true}).
               sort({birthdate:-1, name:1})
```
Here's an example of an efficient index for this query:
```js
> db.customers.createIndex({active:1, birthdate:-1, name:1})
```
View the Indexes used in a Collection
```js
> db.customers.getIndexes()
```
Check if an index is being used on a query
Use explain() in a collection when running a query to see the Execution plan.
This plan provides the details of the execution stages (IXSCAN , COLLSCAN,
FETCH, SORT, etc.). Some of these are:
- The IXSCAN stage indicates the query is using an index and what index is
  being selected.
- The COLLSCAN stage indicates a collection scan is perform, not using any
  indexes.
- The FETCH stage indicates documents are being read from the collection.
- The SORT stage indicates documents are being sorted in memory.
```js
> db.customers.
  explain().
  find({birthdate: {$gte:ISODate("1977-01-01") }, active:true }).
  sort({birthdate:-1, name:1})
```
Cover a query by the Index
An Index covers a query when MongoDB does not need to fetch the data from memory
since all the required data is already returned by the index.
In most cases, we can use projections to return only the required fields and
cover the query. Make sure those fields in the projection are in the index.

By adding the projection `{name:1,birthdate:1,_id:0}` in the previous query,
we can limit the returned fields to only name and birthdate. These fields are
part of the index and when we run the `explain()` command, the execution plan
shows only two stages:
- IXSCAN - Index scan using the compound index
- PROJECTION_COVERED - All the information needed is returned by the index,
  no need to fetch from memory
```js
> db.customers.
  explain().
  find(
    {birthdate: {$gte:ISODate("1977-01-01")}, active:true},
    {name:1, birthdate:1, _id:0}).
  sort({birthdate:-1, name:1})
```

### Deleting Indexes
Delete a single index by name or by key, delete several indexes, delete all the
indexes in the collection (except the index by the `_id` field)
```js
> db.customers.dropIndex('active_1_birthdate_-1_name_1')
> db.customers.dropIndex({active:1, birthdate:-1, name:1})
> db.collection.dropIndexes(['index1name', 'index2name', 'index3name'])
> db.customers.dropIndexes()
```
On production environment, it is recommended to hide index before deleting it.
A hidden index does not support queries but gets updated on inserts. One can
`explain()` to see wether the hidding the index decreses query performance.
If so, the index can be unhidden. The latter is much faster than recreating
a dropped index.
```js
> db.customers.hideIndex({active:1, birthdate:-1, name:1})
> db.customers.unhideIndex({active:1, birthdate:-1, name:1})
```

### Data Modeling Into
Data that is accessed together should be stored together.
Types of relationships between data entities:
- one-to-one
- one-to-many
- many-to-many
One-to-many relationship can be modeled via embedding (aka nested documents) or
via referencing, i.e. keeping a reference (e.g. ID) to the document located
elsewhere (e.g. in another collection). Embedding usually results a better
performance than referencing because data that is accessed together are stored
together. I.e. all the data can be read/updated in a single operation without
need for searching and "joining" documents from different collection. However,
one should avoid embedding antipatterns that are large documents (document
limit is 16MB) and unbounded subarrays which grow limitlessly over time.

Embedding:
- Pro: single query to retrieve data
- Pro: single operation to update/delete data
- Con: Data dupliction
- Con: Large documents

Referencing:
- Pro: no duplication
- Pro: smaller documents
- Con: need to join data from multiple documents

Common schema anti-patterns:
- Massive arrays
- Massive number of collections
- Bloated documents
- Unnecessary indexes
- Queries without indexes
- Data that accessed together but stored in different collections


### Transactions
The code that's used to complete a multi-document transaction:
```js
> const session = db.getMongo().startSession()
> session.startTransaction()
> const account = session.getDatabase('<db_name>'')
                         .getCollection('<collectioin_name>')
> // Here are updates for multiple documents, e.g. with the `.updateOne()` function
> session.commitTransaction()
```
In you find youself in a scenario when, for instance, you made something wrong
and want to cancel the operations in a uncommited transaction, please use:
```js
> session.abortTransaction()
```
