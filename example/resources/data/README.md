# File types
Different file types which are uploaded to stack in current example

## CSV
```sql
CREATE TABLE iris (
  sepal_length varchar,
  sepal_width varchar,
  petal_length varchar,
  petal_width varchar,
  species varchar
)
WITH (
  format = 'CSV',
  external_location='s3a://hive/data/csv/',
  skip_header_line_count=1
);
```

`NB!` Hive supports csv int types for columns.
You can create a table for `csv` file format using `hive-metastore`.
```sql
CREATE EXTERNAL TABLE iris (sepal_length DECIMAL, sepal_width DECIMAL,
petal_length DECIMAL, petal_width DECIMAL, species STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
LOCATION 's3a://hive/data/csv/'
TBLPROPERTIES ("skip.header.line.count"="1");
```

## JSON

```sql
CREATE TABLE somejson (
  description varchar,
  foo ROW (
    bar varchar,
    quux varchar,
    level1 ROW (
      l2string varchar,
      l2struct ROW (
        level3 varchar
      )
    )
  ),
  wibble varchar,
  wobble ARRAY (
    ROW (
      entry int,
      EntryDetails ROW (
        details varchar,
        details2 int
      )
    )
  )
)
WITH (
  format = 'JSON',
  external_location = 's3a://hive/data/json/'
);
```

## AVRO

```sql
CREATE TABLE tweets (
  username varchar,
  tweet varchar,
  timestamp bigint
)
WITH (
  format = 'AVRO',
  external_location='s3a://hive/data/avro-tweet/'
);
```

## PROTOBUF
Reference to [using-protobuf-parquet](https://costimuraru.wordpress.com/2018/04/26/using-protobuf-parquet-with-aws-athena-presto-or-hive/)

todo
```sql

```
