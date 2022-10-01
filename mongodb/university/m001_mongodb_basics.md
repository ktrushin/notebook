# M001 MongoDB Basics

## Export and import
Please see the [documentation](https://docs.mongodb.com/manual/reference/connection-string/#connections-dns-seedlist)
for more details on the mongodb URI
```shell
$ mongodump --uri "mongodb+srv://<your username>:<your password>@<your cluster>.mongodb.net/sample_supplies"
$ mongoexport --uri="mongodb+srv://<your username>:<your password>@<your cluster>.mongodb.net/sample_supplies" --collection=sales --out=sales.json
$ mongorestore --uri "mongodb+srv://<your username>:<your password>@<your cluster>.mongodb.net/sample_supplies"  --drop dump
$ mongoimport --uri="mongodb+srv://<your username>:<your password>@<your cluster>.mongodb.net/sample_supplies" --drop sales.json
```

## CRUD commands
```js
$ mongo "mongodb+srv://<username>:<password>@<cluster>.mongodb.net/admin"
> show dbs
> use sample_training
> show collections
> db.zips.find({"state": "NY"})
> db.zips.find({"state": "NY"}).count()
> db.zips.find({"state": "NY", "city": "ALBANY"})
> db.zips.find({"state": "NY", "city": "ALBANY"}).pretty()
>
> db.inspections.insert({
      "id" : "10021-2015-ENFO",
      "certificate_number" : 9278806,
      "business_name" : "ATLIXCO DELI GROCERY INC.",
      "date" : "Feb 20 2015",
      "result" : "No Violation Issued",
      "sector" : "Cigarette Retail Dealer - 127",
      "address" : {
              "city" : "RIDGEWOOD",
              "zip" : 11385,
              "street" : "MENAHAN ST",
              "number" : 1712
         }
  })
> db.inspections.find({"id" : "10021-2015-ENFO", "certificate_number" : 9278806}).pretty()
>
> db.inspections.insert([{ "_id": 1, "test": 1 },{ "_id": 1, "test": 2 },
                       { "_id": 3, "test": 3 }],{ "ordered": false })
>
> db.zips.updateMany({ "city": "HUDSON" }, { "$inc": { "pop": 10 } })
> db.zips.updateOne({ "zip": "12534" }, { "$set": { "population": 17630 } })
> db.grades.updateOne({"student_id": 250, "class_id": 339},
                      {"$push": {"scores": {"type": "extra credit", "score": 100}}})
>
> db.inspections.deleteMany({"test": 1})
>
> db.inspection.drop()
```

### Query Operators
```js
> db.trips.find({ "tripduration": { "$lte" : 70 },
                  "usertype": { "$ne": "Subscriber" } }).pretty()
> db.trips.find({ "tripduration": { "$lte" : 70 },
                  "usertype": { "$eq": "Customer" }}).pretty()
> db.trips.find({ "tripduration": { "$lte" : 70 },
                  "usertype": "Customer" }).pretty()
> db.routes.find({"$and": [{"$or" :[{"dst_airport": "KZN"}, {"src_airport": "KZN"}]},
                           {"$or" :[{"airplane": "CR2"}, {"airplane": "A81"}]}
                          ]}).pretty()
> db.trips.find({ "$expr": { "$and": [ { "$gt": [ "$tripduration", 1200 ]},
                           { "$eq": [ "$end station id", "$start station id" ]}
                         ]}}).count()
```

### Array Operators, projection, sub-documents
```js
> db.listingsAndReviews.find({ "amenities": {
                                    "$size": 20,
                                    "$all": [ "Internet", "Wifi",  "Kitchen",
                                             "Heating", "Family/kid friendly",
                                             "Washer", "Dryer", "Essentials",
                                             "Shampoo", "Hangers",
                                             "Hair dryer", "Iron",
                                             "Laptop friendly workspace" ]
                                           }
                              }).pretty()
> db.listingsAndReviews.find({ "amenities":
          { "$size": 20, "$all": [ "Internet", "Wifi",  "Kitchen", "Heating",
                                   "Family/kid friendly", "Washer", "Dryer",
                                   "Essentials", "Shampoo", "Hangers",
                                   "Hair dryer", "Iron",
                                   "Laptop friendly workspace" ] } },
                              {"price": 1, "address": 1}).pretty()
>
> db.listingsAndReviews.find({ "amenities": "Wifi" },
                             { "price": 1, "address": 1, "_id": 0 }).pretty()
> db.listingsAndReviews.find({ "amenities": "Wifi" },
                             { "price": 1, "address": 1,
                               "_id": 0, "maximum_nights":0 }).pretty()
> db.grades.find({"class_id": 431},
                 {"scores": {"$elemMatch": {"score": {"$gt": 85}}}}).pretty()
> db.grades.find({"scores": {"$elemMatch": {"type": "extra credit"}}}).pretty()
>
> db.companies.find({"relationships.0.person.first_name": "Mark",
                     "relationships.0.title": {"$regex": "CEO"}},
                    {"name": 1}).pretty()
> db.companies.find(
  {
    "relationships": {
      "$elemMatch": {"is_past": true, "person.first_name": "Mark"}
    }
  },
  {"name": 1}
).pretty()
```

## Indexing and aggregation pipeline
### Aggregation
```js
> db.listingsAndReviews.aggregate([
                                    { "$match": { "amenities": "Wifi" } },
                                    { "$project": { "price": 1,
                                                    "address": 1,
                                                    "_id": 0 }}]).pretty()
> db.listingsAndReviews.aggregate([
                                    { "$project": { "address": 1, "_id": 0 }},
                                    { "$group": { "_id": "$address.country",
                                                  "count": { "$sum": 1 } } }
                                  ])
> db.listingsAndReviews.aggregate([
      {$project: {room_type: 1, _id: 0}},
      {$group: {_id: {"$room_type"}}}
  ])
```
### sort and limit
```js
> use sample_training
> db.zips.find().sort({ "pop": 1 }).limit(1)
> db.zips.find({ "pop": 0 }).count()
> db.zips.find().sort({ "pop": -1 }).limit(1)
> db.zips.find().sort({ "pop": -1 }).limit(10)
> db.zips.find().sort({ "pop": 1, "city": -1 })
```
### upsert
```js
> db.iot.updateOne({ "sensor": r.sensor, "date": r.date,
                     "valcount": { "$lt": 48 } },
                           { "$push": { "readings": { "v": r.value, "t": r.time } },
                          "$inc": { "valcount": 1, "total": r.value } },
                   { "upsert": true })
```

